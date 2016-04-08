/* linux/arch/arm/mach-exynos4/cpuidle.c
 *
 * Copyright (c) 2011 Samsung Electronics Co., Ltd.
 *		http://www.samsung.com
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
*/

#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/cpuidle.h>
#include <linux/cpu_pm.h>
#include <linux/io.h>
#include <linux/export.h>
#include <linux/time.h>

#include <asm/proc-fns.h>
#include <asm/smp_scu.h>
#include <asm/suspend.h>
#include <asm/unified.h>
#include <asm/cpuidle.h>
#include <mach/regs-clock.h>
#include <mach/regs-pmu.h>

#include <plat/cpu.h>

#include <plat/devs.h>
#include <plat/regs-serial.h>
#include <plat/gpio-cfg.h>
#include <plat/gpio-core.h>
#include <plat/usb-phy.h>
#include <plat/clock.h>

#define CTRL_FORCE_SHIFT        (0x7)
#define CTRL_FORCE_MASK         (0x1FF)
#define CTRL_LOCK_VALUE_SHIFT   (0x8)
#define CTRL_LOCK_VALUE_MASK    (0x1FF)
#define MIF_MAX_FREQ		(825000)

static void __iomem *regs_lpddrphy0;
static void __iomem *regs_lpddrphy1;

extern int pwm_check_enable_cnt(void);
#if defined (CONFIG_EXYNOS_CLUSTER_POWER_DOWN)
static cputime64_t cluster_off_time = 0;
static unsigned long long last_time = 0;
static bool cluster_off_flag = false;

static spinlock_t c2_state_lock;

#define CLUSTER_OFF_TARGET_RESIDENCY	3000
#endif

#define REG_DIRECTGO_ADDR	(S5P_VA_SYSRAM_NS + 0x24)
#define REG_DIRECTGO_FLAG	(S5P_VA_SYSRAM_NS + 0x20)

#define EXYNOS_CHECK_DIRECTGO	0xFCBA0D10
#define EXYNOS_CHECK_C2		0xABAC0000
#define EXYNOS_CHECK_LPA	0xABAD0000
#define EXYNOS_CHECK_DSTOP	0xABAE0000

#ifdef CONFIG_EXYNOS_DECON_DISPLAY
extern unsigned int *ref_power_status;
enum s3c_fb_pm_status {
	POWER_ON = 0,
	POWER_DOWN = 1,
	POWER_HIBER_DOWN = 2,
};
#endif

#ifdef CONFIG_SEC_PM

#if defined(CONFIG_DISABLE_C2_BOOT) && !defined(CONFIG_SEC_FACTORY)
#define CPUIDLE_ENABLE_MASK (ENABLE_C3_AFTR | ENABLE_C3_LPA | ENABLE_C3_DSTOP)
#else
#define CPUIDLE_ENABLE_MASK (ENABLE_C2 | ENABLE_C3_AFTR | ENABLE_C3_LPA | ENABLE_C3_DSTOP)
#endif

static enum {
	ENABLE_C2	= BIT(0),
	ENABLE_C3_AFTR	= BIT(1),
	ENABLE_C3_LPA	= BIT(2),
	ENABLE_C3_DSTOP	= BIT(3),
} enable_mask = CPUIDLE_ENABLE_MASK;

DEFINE_SPINLOCK(enable_mask_lock);

static int set_enable_mask(const char *val, const struct kernel_param *kp)
{
	int rv = param_set_uint(val, kp);
	unsigned long flags;

	pr_info("%s: val=%s, enable_maks=%d\n", __func__, val, enable_mask);

	if (rv)
		return rv;

	spin_lock_irqsave(&enable_mask_lock, flags);

#include "common.h"

#define REG_DIRECTGO_ADDR	(samsung_rev() == EXYNOS4210_REV_1_1 ? \
			S5P_INFORM7 : (samsung_rev() == EXYNOS4210_REV_1_0 ? \
			(S5P_VA_SYSRAM + 0x24) : S5P_INFORM0))
#define REG_DIRECTGO_FLAG	(samsung_rev() == EXYNOS4210_REV_1_1 ? \
			S5P_INFORM6 : (samsung_rev() == EXYNOS4210_REV_1_0 ? \
			(S5P_VA_SYSRAM + 0x20) : S5P_INFORM1))

#define S5P_CHECK_AFTR		0xFCBA0D10

static int exynos4_enter_lowpower(struct cpuidle_device *dev,
				struct cpuidle_driver *drv,
				int index);

static DEFINE_PER_CPU(struct cpuidle_device, exynos4_cpuidle_device);

static struct cpuidle_driver exynos4_idle_driver = {
	.name			= "exynos4_idle",
	.owner			= THIS_MODULE,
	.states = {
		[0] = ARM_CPUIDLE_WFI_STATE,
		[1] = {
			.enter			= exynos4_enter_lowpower,
			.exit_latency		= 300,
			.target_residency	= 100000,
			.flags			= CPUIDLE_FLAG_TIME_VALID,
			.name			= "C1",
			.desc			= "ARM power down",
		},
	},
	.state_count = 2,
	.safe_state_index = 0,
};

/* Ext-GIC nIRQ/nFIQ is the only wakeup source in AFTR */
static void exynos4_set_wakeupmask(void)
{
	__raw_writel(0x0000ff3e, S5P_WAKEUP_MASK);
}

static unsigned int g_pwr_ctrl, g_diag_reg;

static void save_cpu_arch_register(void)
{
	/*read power control register*/
	asm("mrc p15, 0, %0, c15, c0, 0" : "=r"(g_pwr_ctrl) : : "cc");
	/*read diagnostic register*/
	asm("mrc p15, 0, %0, c15, c0, 1" : "=r"(g_diag_reg) : : "cc");
	return;
}

static void restore_cpu_arch_register(void)
{
	/*write power control register*/
	asm("mcr p15, 0, %0, c15, c0, 0" : : "r"(g_pwr_ctrl) : "cc");
	/*write diagnostic register*/
	asm("mcr p15, 0, %0, c15, c0, 1" : : "r"(g_diag_reg) : "cc");
	return;
}

static int idle_finisher(unsigned long flags)
{
	exynos_smc(SMC_CMD_SAVE, OP_TYPE_CORE, SMC_POWERSTATE_IDLE, 0);
	exynos_smc(SMC_CMD_SHUTDOWN, OP_TYPE_CLUSTER, SMC_POWERSTATE_IDLE, 0);

	return 1;
}

#if defined (CONFIG_EXYNOS_CPUIDLE_C2)
#if defined (CONFIG_EXYNOS_CLUSTER_POWER_DOWN)
#ifdef CONFIG_ARM_EXYNOS_MP_CPUFREQ
static bool disabled_c3 = false;

static void exynos_disable_c3_idle(bool disable)
{
	disabled_c3 = disable;
}
#endif

#define L2_OFF		(1 << 0)
#define L2_CCI_OFF	(1 << 1)
#define CMU_OFF		(1 << 2)
#endif

#if defined(CONFIG_SCHED_HMP)
static __maybe_unused int check_matched_state(int cpu_id, struct cpumask *matched_state, const struct cpumask *cpu_group)
{
	ktime_t now = ktime_get();
	struct clock_event_device *dev;
	int cpu;

	if (disabled_c3)
		return 0;

	for_each_cpu_and(cpu, cpu_possible_mask, cpu_group) {
		if (cpu_id == cpu)
			continue;

		dev = per_cpu(tick_cpu_device, cpu).evtdev;
		if (!cpumask_test_cpu(cpu, matched_state))
			return 0;

		if (ktime_to_us(ktime_sub(dev->next_event, now)) < CLUSTER_OFF_TARGET_RESIDENCY)
			return 0;
	}
	return 1;
}
#endif

struct cpumask cpu_c2_state;

static int c2_finisher(unsigned long flags)
{
	unsigned int kind = OP_TYPE_CORE;
	unsigned int param = 0;

#if defined (CONFIG_SOC_EXYNOS5430_REV_1) && defined (CONFIG_EXYNOS_CLUSTER_POWER_DOWN)
	unsigned int cpuid = smp_processor_id();
#endif
	exynos_smc(SMC_CMD_SAVE, OP_TYPE_CORE, SMC_POWERSTATE_IDLE, 0);

#if defined (CONFIG_EXYNOS_CLUSTER_POWER_DOWN)
	if (flags & L2_CCI_OFF) {
		sec_debug_task_log_msg(cpuid, "clstr");
		exynos_cpu_sequencer_ctrl(true);
		cluster_off_flag = true;
		last_time = get_jiffies_64();

		kind = OP_TYPE_CLUSTER;
	}
#endif
	if (flags & CMU_OFF)
		param = 1;

	exynos_smc(SMC_CMD_SHUTDOWN, kind, SMC_POWERSTATE_IDLE, param);

	/*
	 * Secure monitor disables the SMP bit and takes the CPU out of the
	 * coherency domain.
	 */
	local_flush_tlb_all();

>>>>>>> e7523cb... Source Drop - N910CXXU2DPCB
	return 1;
}

static int exynos4_enter_core0_aftr(struct cpuidle_device *dev,
				struct cpuidle_driver *drv,
				int index)
{
	unsigned long tmp;

	exynos4_set_wakeupmask();

	/* Set value of power down register for aftr mode */
	exynos_sys_powerdown_conf(SYS_AFTR);

	__raw_writel(virt_to_phys(s3c_cpu_resume), REG_DIRECTGO_ADDR);
	__raw_writel(S5P_CHECK_AFTR, REG_DIRECTGO_FLAG);

	save_cpu_arch_register();

	/* Setting Central Sequence Register for power down mode */
	tmp = __raw_readl(S5P_CENTRAL_SEQ_CONFIGURATION);
	tmp &= ~S5P_CENTRAL_LOWPWR_CFG;
	__raw_writel(tmp, S5P_CENTRAL_SEQ_CONFIGURATION);

	cpu_pm_enter();
	cpu_suspend(0, idle_finisher);

#ifdef CONFIG_SMP
	if (!soc_is_exynos5250())
		scu_enable(S5P_VA_SCU);
#endif
	cpu_pm_exit();

	restore_cpu_arch_register();

<<<<<<< HEAD
=======
#ifdef CONFIG_EXYNOS_IDLE_CLOCK_DOWN
	exynos_idle_clock_down(true, ARM);
	exynos_idle_clock_down(true, KFC);
#endif

	aftr_wakeup_stat[aftr_wakeup_count].buf_cnt = aftr_wakeup_count;
	aftr_wakeup_stat[aftr_wakeup_count].wakeup_stat = __raw_readl(EXYNOS5430_WAKEUP_STAT);
	aftr_wakeup_stat[aftr_wakeup_count].wakeup_stat1 = __raw_readl(EXYNOS5430_WAKEUP_STAT1);
	aftr_wakeup_stat[aftr_wakeup_count].wakeup_stat2 = __raw_readl(EXYNOS5430_WAKEUP_STAT2);
	aftr_wakeup_count++;
	if (aftr_wakeup_count >= EXYNOS_WAKEUP_STAT_BUF_SIZE)
		aftr_wakeup_count = 0;

	/* Clear wakeup state register */
	__raw_writel(0x0, EXYNOS5430_WAKEUP_STAT);
	__raw_writel(0x0, EXYNOS5430_WAKEUP_STAT1);
	__raw_writel(0x0, EXYNOS5430_WAKEUP_STAT2);

	do_gettimeofday(&after);

#ifdef CONFIG_SEC_PM_DEBUG
	if (log_en & ENABLE_C3_AFTR)
		pr_info("---aftr\n");
#endif

	sec_debug_task_log_msg(cpuid, "aftr-");

	idle_time = (after.tv_sec - before.tv_sec) * USEC_PER_SEC +
		    (after.tv_usec - before.tv_usec);

	dev->last_residency = idle_time;
	return index;
}

static struct sleep_save exynos5_lpa_save[] = {
	/* CMU side */
	SAVE_ITEM(EXYNOS5430_ENABLE_IP_TOP),
	SAVE_ITEM(EXYNOS5430_ENABLE_IP_FSYS0),
	SAVE_ITEM(EXYNOS5430_ENABLE_IP_PERIC0),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_TOP_PERIC1),
	SAVE_ITEM(EXYNOS5430_ENABLE_IP_EGL1),
	SAVE_ITEM(EXYNOS5430_ENABLE_IP_KFC1),

	SAVE_ITEM(EXYNOS5430_ENABLE_IP_MIF1),
	SAVE_ITEM(EXYNOS5430_ENABLE_IP_CPIF0),

	SAVE_ITEM(EXYNOS5430_SRC_SEL_TOP0),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_TOP1),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_TOP2),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_TOP3),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_TOP_MSCL),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_TOP_CAM1),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_TOP_DISP),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_TOP_FSYS0),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_TOP_FSYS1),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_TOP_PERIC0),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_TOP_PERIC1),

	SAVE_ITEM(EXYNOS5430_ISP_PLL_CON0),
	SAVE_ITEM(EXYNOS5430_ISP_PLL_CON1),
	SAVE_ITEM(EXYNOS5430_AUD_PLL_CON0),
	SAVE_ITEM(EXYNOS5430_AUD_PLL_CON1),
	SAVE_ITEM(EXYNOS5430_AUD_PLL_CON2),

	SAVE_ITEM(EXYNOS5430_DIV_TOP0),
	SAVE_ITEM(EXYNOS5430_DIV_TOP1),
	SAVE_ITEM(EXYNOS5430_DIV_TOP2),
	SAVE_ITEM(EXYNOS5430_DIV_TOP3),
	SAVE_ITEM(EXYNOS5430_DIV_TOP_MSCL),
	SAVE_ITEM(EXYNOS5430_DIV_TOP_CAM10),
	SAVE_ITEM(EXYNOS5430_DIV_TOP_CAM11),
	SAVE_ITEM(EXYNOS5430_DIV_TOP_FSYS0),
	SAVE_ITEM(EXYNOS5430_DIV_TOP_FSYS1),
	SAVE_ITEM(EXYNOS5430_DIV_TOP_FSYS2),
	SAVE_ITEM(EXYNOS5430_DIV_TOP_PERIC0),
	SAVE_ITEM(EXYNOS5430_DIV_TOP_PERIC1),
	SAVE_ITEM(EXYNOS5430_DIV_TOP_PERIC2),
	SAVE_ITEM(EXYNOS5430_DIV_TOP_PERIC3),

	SAVE_ITEM(EXYNOS5430_MEM0_PLL_CON0),
	SAVE_ITEM(EXYNOS5430_MEM0_PLL_CON1),
	SAVE_ITEM(EXYNOS5430_MEM1_PLL_CON0),
	SAVE_ITEM(EXYNOS5430_MEM1_PLL_CON1),
	SAVE_ITEM(EXYNOS5430_BUS_PLL_CON0),
	SAVE_ITEM(EXYNOS5430_BUS_PLL_CON1),
	SAVE_ITEM(EXYNOS5430_MFC_PLL_CON0),
	SAVE_ITEM(EXYNOS5430_MFC_PLL_CON1),
	SAVE_ITEM(EXYNOS5430_MPHY_PLL_CON0),
	SAVE_ITEM(EXYNOS5430_MPHY_PLL_CON1),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_MIF0),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_MIF1),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_MIF2),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_MIF3),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_MIF4),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_MIF5),
	SAVE_ITEM(EXYNOS5430_DIV_MIF1),
	SAVE_ITEM(EXYNOS5430_DIV_MIF2),
	SAVE_ITEM(EXYNOS5430_DIV_MIF3),
	SAVE_ITEM(EXYNOS5430_DIV_MIF4),
	SAVE_ITEM(EXYNOS5430_DIV_MIF5),

	SAVE_ITEM(EXYNOS5430_SRC_SEL_EGL0),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_EGL1),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_EGL2),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_KFC0),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_KFC1),
	SAVE_ITEM(EXYNOS5430_SRC_SEL_KFC2),

	SAVE_ITEM(EXYNOS5430_SRC_SEL_BUS2),

	SAVE_ITEM(EXYNOS5430_DIV_EGL0),
	SAVE_ITEM(EXYNOS5430_DIV_EGL1),

	SAVE_ITEM(EXYNOS5430_DIV_KFC0),
	SAVE_ITEM(EXYNOS5430_DIV_KFC1),
	SAVE_ITEM(EXYNOS5430_DIV_BUS1),
	SAVE_ITEM(EXYNOS5430_DIV_BUS2),
	/* CLK_SRC */
	SAVE_ITEM(EXYNOS5430_SRC_ENABLE_TOP0),
	SAVE_ITEM(EXYNOS5430_SRC_ENABLE_TOP2),
	SAVE_ITEM(EXYNOS5430_SRC_ENABLE_TOP3),
#ifndef CONFIG_SOC_EXYNOS5430_REV_0
	SAVE_ITEM(EXYNOS5430_SRC_ENABLE_TOP4),
#endif
	SAVE_ITEM(EXYNOS5430_SRC_ENABLE_TOP_MSCL),
	SAVE_ITEM(EXYNOS5430_SRC_ENABLE_TOP_CAM1),
	SAVE_ITEM(EXYNOS5430_SRC_ENABLE_TOP_DISP),
};

static struct sleep_save exynos5_lpa_save_before[] = {
        SAVE_ITEM(EXYNOS5430_ENABLE_ACLK_MIF3),
        SAVE_ITEM(EXYNOS5430_ENABLE_ACLK_TOP),
        SAVE_ITEM(EXYNOS5430_SRC_SEL_BUS2),
        SAVE_ITEM(EXYNOS5430_SRC_SEL_FSYS0),
};

static struct sleep_save exynos5_set_clksrc[] = {
	{ .reg = EXYNOS5430_ENABLE_IP_FSYS0,	.val = 0x00007dfb, },
	{ .reg = EXYNOS5430_ENABLE_IP_PERIC0,	.val = 0x1fffffff, },
	{ .reg = EXYNOS5430_SRC_SEL_TOP_PERIC1,	.val = 0x00000011, },
	{ .reg = EXYNOS5430_ENABLE_IP_EGL1,	.val = 0x00000fff, },
	{ .reg = EXYNOS5430_ENABLE_IP_KFC1,	.val = 0x00000fff, },
	{ .reg = EXYNOS5430_ENABLE_IP_MIF1,	.val = 0x01fffff7, },
	{ .reg = EXYNOS5430_ENABLE_IP_CPIF0,	.val = 0x000FF000, },
};

static struct sleep_save exynos5_set_clksrc_after[] = {
        { .reg = EXYNOS5430_SRC_SEL_FSYS0,	.val = 0x00000000, },
        { .reg = EXYNOS5430_SRC_SEL_BUS2,	.val = 0x00000000, },
        { .reg = EXYNOS5430_ENABLE_ACLK_TOP,	.val = 0x03e8fffd, },
        { .reg = EXYNOS5430_ENABLE_ACLK_MIF3,	.val = 0x00000003, },
};

static void exynos_save_mif_dll_status(void)
{
	unsigned int tmp;

	tmp = __raw_readl(regs_lpddrphy0 + 0xB0);

	/* 1. If 5th bit indicate '1', save '1' */
	if (tmp & (0x1 << 5))
		__raw_writel(0x1, EXYNOS5430_DREX_CALN2);
	else
		__raw_writel(0x0, EXYNOS5430_DREX_CALN2);

	/* 2. Write 0 to 12bit of CLK_MUX_ENABLE_MIF1 before LPA/DSTOP */
	tmp &= ~(0x1 << 5);
	__raw_writel(tmp, regs_lpddrphy0 + 0xB0);
	tmp = __raw_readl(regs_lpddrphy1 + 0xB0);
	tmp &= ~(0x1 << 5);
	__raw_writel(tmp, regs_lpddrphy1 + 0xB0);
}

static void exynos_restore_mif_dll_status(void)
{
	unsigned int tmp;

	tmp = __raw_readl(regs_lpddrphy0 + 0xB0);
	if (__raw_readl(EXYNOS5430_DREX_CALN2))
		tmp |= (0x1 << 5);
	else
		tmp &= ~(0x1 << 5);
	__raw_writel(tmp, regs_lpddrphy0 + 0xB0);

	tmp = __raw_readl(regs_lpddrphy1 + 0xB0);
	if (__raw_readl(EXYNOS5430_DREX_CALN2))
		tmp |= (0x1 << 5);
	else
		tmp &= ~(0x1 << 5);
	__raw_writel(tmp, regs_lpddrphy1 + 0xB0);
}

static int exynos_enter_core0_lpa(struct cpuidle_device *dev,
				struct cpuidle_driver *drv,
				int lp_mode, int index, int enter_mode)
{
	struct timeval before, after;
	int idle_time, ret = 0;
	unsigned long tmp;
	unsigned int cpuid = smp_processor_id();
	unsigned int cpu_offset;
	unsigned int early_wakeup_flag = 0;

	/*
	 * Before enter central sequence mode, clock src register have to set
	 */
	s3c_pm_do_save(exynos5_lpa_save, ARRAY_SIZE(exynos5_lpa_save));
	s3c_pm_do_restore_core(exynos5_set_clksrc,
			       ARRAY_SIZE(exynos5_set_clksrc));

	/* Before enter central sequence mode, MPHY_PLL should be enable */
	tmp = __raw_readl(EXYNOS5430_MPHY_PLL_CON0);
	tmp |= (1 << 31);
	__raw_writel(tmp, EXYNOS5430_MPHY_PLL_CON0);

	if (enter_mode == EXYNOS_CHECK_LPA)
		sec_debug_task_log_msg(cpuid, "lpa+");
	else
		sec_debug_task_log_msg(cpuid, "dstop+");

#ifdef CONFIG_SEC_PM_DEBUG
	if ((log_en & ENABLE_C3_LPA) && (enter_mode == EXYNOS_CHECK_LPA))
		pr_info("+++lpa\n");
	else if ((log_en & ENABLE_C3_DSTOP) && (enter_mode != EXYNOS_CHECK_LPA))
		pr_info("+++dstop\n");
#endif

	do_gettimeofday(&before);

	/* Configure GPIO Power down control register */
#ifdef MUST_MODIFY
	exynos_set_lpa_pdn(S3C_GPIO_END);
#endif

	__raw_writel(virt_to_phys(s3c_cpu_resume), REG_DIRECTGO_ADDR);
	__raw_writel(EXYNOS_CHECK_DIRECTGO, REG_DIRECTGO_FLAG);

	/* Set value of power down register for aftr mode */
	if (enter_mode == EXYNOS_CHECK_LPA) {
		exynos_sys_powerdown_conf(SYS_LPA);
		__raw_writel(0x40001000, EXYNOS5430_WAKEUP_MASK);
	} else {
		exynos_sys_powerdown_conf(SYS_DSTOP);
		__raw_writel(0x40003000, EXYNOS5430_WAKEUP_MASK);
	}

>>>>>>> e7523cb... Source Drop - N910CXXU2DPCB
	/*
	 * If PMU failed while entering sleep mode, WFI will be
	 * ignored by PMU and then exiting cpu_do_idle().
	 * S5P_CENTRAL_LOWPWR_CFG bit will not be set automatically
	 * in this situation.
	 */
<<<<<<< HEAD
	tmp = __raw_readl(S5P_CENTRAL_SEQ_CONFIGURATION);
	if (!(tmp & S5P_CENTRAL_LOWPWR_CFG)) {
		tmp |= S5P_CENTRAL_LOWPWR_CFG;
		__raw_writel(tmp, S5P_CENTRAL_SEQ_CONFIGURATION);
	}

=======
	__raw_writel(0xFFFF0000, EXYNOS5430_WAKEUP_MASK1);
	__raw_writel(0xFFFF0000, EXYNOS5430_WAKEUP_MASK2);

#ifdef CONFIG_EXYNOS_IDLE_CLOCK_DOWN
	exynos_idle_clock_down(false, ARM);
	exynos_idle_clock_down(false, KFC);
#endif

	save_cpu_arch_register();

	/* Setting Central Sequence Register for power down mode */
	cpu_offset = cpuid ^ 0x4;
	tmp = __raw_readl(EXYNOS_CENTRAL_SEQ_CONFIGURATION);
	tmp &= ~EXYNOS_CENTRAL_LOWPWR_CFG;
	__raw_writel(tmp, EXYNOS_CENTRAL_SEQ_CONFIGURATION);

	do {
		/* Waiting for flushing UART fifo */
	} while (exynos_uart_fifo_check());

	set_boot_flag(cpuid, C2_STATE);

	cpu_pm_enter();
	exynos_lpa_enter();

	s3c_pm_do_save(exynos5_lpa_save_before, ARRAY_SIZE(exynos5_lpa_save_before));
	s3c_pm_do_restore_core(exynos5_set_clksrc_after,
			       ARRAY_SIZE(exynos5_set_clksrc_after));

	if (lp_mode == SYS_ALPA)
		__raw_writel(0x1, EXYNOS5430_PMU_SYNC_CTRL);

	/* This is W/A for gating Mclk during LPA/DSTOP */
	/* Save flag to confirm if current mode is LPA or DSTOP */
	__raw_writel(EXYNOS_CHECK_DIRECTGO, EXYNOS5430_DREX_CALN1);
	exynos_save_mif_dll_status();

	ret = cpu_suspend(0, idle_finisher);
	if (ret) {
		tmp = __raw_readl(EXYNOS_CENTRAL_SEQ_CONFIGURATION);
		tmp |= EXYNOS_CENTRAL_LOWPWR_CFG;
		__raw_writel(tmp, EXYNOS_CENTRAL_SEQ_CONFIGURATION);
		early_wakeup_flag = 1;

		exynos_restore_mif_dll_status();
		goto early_wakeup;
	}

	/* For release retention */
	__raw_writel((1 << 28), EXYNOS_PAD_RET_DRAM_OPTION);
	__raw_writel((1 << 28), EXYNOS_PAD_RET_JTAG_OPTION);
	__raw_writel((1 << 28), EXYNOS5430_PAD_RETENTION_MMC2_OPTION);
	__raw_writel((1 << 28), EXYNOS5430_PAD_RETENTION_TOP_OPTION);
	__raw_writel((1 << 28), EXYNOS5430_PAD_RETENTION_UART_OPTION);
	__raw_writel((1 << 28), EXYNOS5430_PAD_RETENTION_MMC0_OPTION);
	__raw_writel((1 << 28), EXYNOS5430_PAD_RETENTION_MMC1_OPTION);
	__raw_writel((1 << 28), EXYNOS5430_PAD_RETENTION_EBIA_OPTION);
	__raw_writel((1 << 28), EXYNOS5430_PAD_RETENTION_EBIB_OPTION);
	__raw_writel((1 << 28), EXYNOS5430_PAD_RETENTION_SPI_OPTION);
	__raw_writel((1 << 28), EXYNOS5430_PAD_RETENTION_MIF_OPTION);
	__raw_writel((1 << 28), EXYNOS5430_PAD_RETENTION_USBXTI_OPTION);
	__raw_writel((1 << 28), EXYNOS5430_PAD_RETENTION_BOOTLDO_OPTION);
	__raw_writel((1 << 28), EXYNOS5430_PAD_RETENTION_UFS_OPTION);
	__raw_writel((1 << 28), EXYNOS5430_PAD_RETENTION_FSYSGENIO_OPTION);

early_wakeup:
	s3c_pm_do_restore_core(exynos5_lpa_save_before,
			       ARRAY_SIZE(exynos5_lpa_save_before));

	samsung_usb_lpa_resume();

	if (lp_mode == SYS_ALPA)
		__raw_writel(0x0, EXYNOS5430_PMU_SYNC_CTRL);

	/* This is W/A for gating Mclk during LPA/DSTOP */
	/* Clear flag  */
	__raw_writel(0, EXYNOS5430_DREX_CALN1);

	clear_boot_flag(cpuid, C2_STATE);

	exynos_lpa_exit();
	cpu_pm_exit();

	restore_cpu_arch_register();

#ifdef CONFIG_EXYNOS_IDLE_CLOCK_DOWN
	exynos_idle_clock_down(true, ARM);
	exynos_idle_clock_down(true, KFC);
#endif

	s3c_pm_do_restore_core(exynos5_lpa_save,
			       ARRAY_SIZE(exynos5_lpa_save));

	lpa_wakeup_stat[lpa_wakeup_count].buf_cnt = lpa_wakeup_count;
	lpa_wakeup_stat[lpa_wakeup_count].wakeup_stat = __raw_readl(EXYNOS5430_WAKEUP_STAT);
	lpa_wakeup_stat[lpa_wakeup_count].wakeup_stat1 = __raw_readl(EXYNOS5430_WAKEUP_STAT1);
	lpa_wakeup_stat[lpa_wakeup_count].wakeup_stat2 = __raw_readl(EXYNOS5430_WAKEUP_STAT2);
	lpa_wakeup_stat[lpa_wakeup_count].early_wakeup = early_wakeup_flag;
	lpa_wakeup_count++;
	if (lpa_wakeup_count >= EXYNOS_WAKEUP_STAT_BUF_SIZE)
		lpa_wakeup_count = 0;

>>>>>>> e7523cb... Source Drop - N910CXXU2DPCB
	/* Clear wakeup state register */
	__raw_writel(0x0, S5P_WAKEUP_STAT);

	return index;
}

static int exynos4_enter_lowpower(struct cpuidle_device *dev,
				struct cpuidle_driver *drv,
				int index)
{
	int new_index = index;

	/* This mode only can be entered when other core's are offline */
	if (num_online_cpus() > 1)
		new_index = drv->safe_state_index;

	if (new_index == 0)
		return arm_cpuidle_simple_enter(dev, drv, new_index);
	else
		return exynos4_enter_core0_aftr(dev, drv, new_index);
}

static void __init exynos5_core_down_clk(void)
{
	unsigned int tmp;

	/*
	 * Enable arm clock down (in idle) and set arm divider
	 * ratios in WFI/WFE state.
	 */
	tmp = PWR_CTRL1_CORE2_DOWN_RATIO | \
	      PWR_CTRL1_CORE1_DOWN_RATIO | \
	      PWR_CTRL1_DIV2_DOWN_EN	 | \
	      PWR_CTRL1_DIV1_DOWN_EN	 | \
	      PWR_CTRL1_USE_CORE1_WFE	 | \
	      PWR_CTRL1_USE_CORE0_WFE	 | \
	      PWR_CTRL1_USE_CORE1_WFI	 | \
	      PWR_CTRL1_USE_CORE0_WFI;
	__raw_writel(tmp, EXYNOS5_PWR_CTRL1);

	/*
	 * Enable arm clock up (on exiting idle). Set arm divider
	 * ratios when not in idle along with the standby duration
	 * ratios.
	 */
	tmp = PWR_CTRL2_DIV2_UP_EN	 | \
	      PWR_CTRL2_DIV1_UP_EN	 | \
	      PWR_CTRL2_DUR_STANDBY2_VAL | \
	      PWR_CTRL2_DUR_STANDBY1_VAL | \
	      PWR_CTRL2_CORE2_UP_RATIO	 | \
	      PWR_CTRL2_CORE1_UP_RATIO;
	__raw_writel(tmp, EXYNOS5_PWR_CTRL2);
}

static int __init exynos4_init_cpuidle(void)
{
	int cpu_id, ret;
	struct cpuidle_device *device;

	if (soc_is_exynos5250())
		exynos5_core_down_clk();

	ret = cpuidle_register_driver(&exynos4_idle_driver);
	if (ret) {
		printk(KERN_ERR "CPUidle failed to register driver\n");
		return ret;
	}

	for_each_online_cpu(cpu_id) {
		device = &per_cpu(exynos4_cpuidle_device, cpu_id);
		device->cpu = cpu_id;

		/* Support IDLE only */
		if (cpu_id != 0)
			device->state_count = 1;

		ret = cpuidle_register_device(device);
		if (ret) {
			printk(KERN_ERR "CPUidle register device failed\n");
			return ret;
		}
	}

	return 0;
}
device_initcall(exynos4_init_cpuidle);
