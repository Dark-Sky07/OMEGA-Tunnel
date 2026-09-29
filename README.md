# 👑 Omega VPS All In One Optimizer (Grand Master Suite)

<p align="center">
  <img src="https://img.shields.io/badge/Release-v3.0.0--GrandMaster-blue.svg?style=for-the-badge&logo=github" alt="Release v3.0.0" />
  <img src="https://img.shields.io/badge/OS-Ubuntu%20|%20Debian%20|%20CentOS-orange.svg?style=for-the-badge&logo=linux" alt="OS Support" />
  <img src="https://img.shields.io/badge/Panel%20Safety-100%25%20Untouched-success.svg?style=for-the-badge&logo=shield" alt="Panel Safety" />
  <img src="https://img.shields.io/badge/Self--Healing-Watchdog%20%2B%20Auto--Unban-purple.svg?style=for-the-badge&logo=dependabot" alt="Self-Healing" />
  <img src="https://img.shields.io/badge/Language-100%25%20English%20TUI-informational.svg?style=for-the-badge" alt="English TUI" />
</p>

```text
========================================================================
                  ____  __  __ _____ ____    _   
                 / __ \|  \/  | ____/ ___|  / \  
                | |  | | |\/| |  _|| |  _  / _ \ 
                | |__| | |  | | |__| |_| |/ ___ \
                 \____/|_|  |_|_____\____/_/   \_\\

  __     ______  ____     ___        _   _           _             
  \ \   / /  _ \/ ___|   / _ \ _ __ | |_(_)_ __ ___ (_)_______ _ __
   \ \ / /| |_) \___ \  | | | | '_ \| __| | '_ ` _ \| |_  / _ \ '__|
    \ V / |  __/ ___) | | |_| | |_) | |_| | | | | | | |/ /  __/ |  
     \_/  |_|   |____/   \___/| .__/ \__|_|_| |_| |_|_/___\___|_|  
                              |_|                                  
                   All In One Server Suite
========================================================================
```

**Omega VPS All In One Optimizer** یک سوئیت مهندسی‌شده و مافوق‌حرفه‌ای برای تقویت همه‌جانبه سرورهای لینوکس (VPS) است. این پروژه طراحی شده تا بدون نیاز به سرور واسط ایران (Relay/Bridge)، با دور زدن لایه‌های اختلال و فیلترینگ شدید اپراتورها (ایرانسل، همراه اول، رایتل و سامانتل)، سرعت، پایداری و تاب‌آوری اتصالات کاربران را به بالاترین سطح ممکن برساند.

> 🔒 **تضمین ۱۰۰٪ عدم تداخل با پنل (Zero-Downtime Panel Safety):**  
> این اسکریپت به‌هیچ‌وجه به فایل دیتابیس ۳ایکس‌یوآی (`x-ui.db`)، باینری هسته Xray، یا کانفیگ‌های کاربران دست نمی‌زند، سرویس پنل را ری‌استارت نمی‌کند و ارتباط هیچ کاربر آنلاینی را قطع نمی‌کند!

---

## ⚡ نصب سریع و یک‌خطی (One-Liner Install)

تنها با اجرای یک دستور ساده در ترمینال سرور لینوکسی خود، کل سوئیت به همراه دستور سراسری `omega` نصب و آماده اجرا می‌شود:

```bash
curl -fsSL https://raw.githubusercontent.com/Dark-Sky07/OMEGA-Tunnel/arena/01a0d868-omega-tunnel/install.sh | bash
```

پس از نصب، در هر زمان و از هر کجای ترمینال فقط با تایپ کلمه زیر منوی قدرتمند امگا باز می‌شود:

```bash
omega
```

---

## 🛡️ قرارداد ایمنی پنل و مشتریان (Safety Contract)

| مولفه حساس سرور | سیاست و عملکرد Omega Optimizer |
|---|---|
| **دیتابیس پنل (`/etc/x-ui/x-ui.db`)** | **کاملاً دست‌نخورده.** تمام داده‌های امگا در دایرکتوری مستقل `/opt/omega-boost` ذخیره می‌شوند. |
| **هسته Xray (`/usr/local/x-ui/bin`)** | **بدون تغییر و جایگزینی.** هسته رسمی پنل هرگز آپگرید اجباری یا بازنویسی نمی‌شود. |
| **کاربران آنلاین (Active Clients)** | **بدون قطعی.** هیچ دستوری نیاز به ری‌استارت پنل ندارد. سشن کاربران پایدار می‌ماند. |
| **اتصالات WireGuard و WARP** | **محافظت‌شده.** بر خلاف اسکریپت‌های غیراستاندارد، پورت UDP 443 به صورت عمومی بلاک نمی‌شود تا اینترفیس‌های WARP از کار نیفتند. |
| **فایروال سرور** | **قوانین هدفمند با Rollback تمیز.** تغییرات در جدول `mangle` ثبت شده و با ۱ کلیک قابل بازگشت است. |

---

## 🚀 نقشه کامل امکانات (۲۳ ابزار اختصاصی در یک منو)

```text
  --- [ CORE & ONE-CLICK ] ---
  [1]  Run Read-Only Preflight Server Audit
  [2]  ★ ONE-CLICK FULL SERVER OPTIMIZATION (All In One)

  --- [ NETWORK & ANTI-CENSORSHIP ] ---
  [3]  Network & Kernel Tuning (BBR + FQ + sysctl buffer autotuning)
  [4]  Operator Compatibility Booster (Fix Samantel / Mobile PMTU Clamping)
  [5]  Optimize Instagram & Video Streaming (Safe for WARP & Google)
  [6]  Reality SNI & Clean Domain Finder (Test best domains for Reality)
  [7]  Cloudflare Clean IP Scanner (Find best low-latency CDN IPs)
  [8]  Smart Anti-Pollution DNS Cache (High-speed zero-poisoning Anycast)

  --- [ SYSTEM, HARDWARE & REPUTATION ] ---
  [9]  System & Hardware Tuning (RAM, Ulimit 1M, Logs 200M)
  [10] Smart Swap Memory Manager (Dynamic suggestions based on RAM)
  [11] IP Reputation & Google/ChatGPT Unban Healer (Auto-Remediation)
  [12] Security & Anti-Bruteforce Hardening (Fail2ban + Ping Shield)
  [13] Panel & Disaster Recovery Backup (1-Click Backup & Restore)
  [14] Automated Nightly Janitor Cronjob (Memory & Cache Cleaner)
  [15] Update System Packages & Install Essential Tools

  --- [ SELF-HEALING & ALERTS ] ---
  [16] 24/7 Panel & Xray Core Auto-Healing Watchdog (Zero-Downtime)
  [17] Telegram Bot Instant Alerts (Crashes, Unbans, & Backups)

  --- [ MONITORING & DIAGNOSTICS ] ---
  [18] Iran Operators Latency & Packet Loss Probe (19 targets across MCI/Irancell/ADSL)
  [19] Iran-Foreign Tunnel & Bridge Health Doctor (Jitter & Packet Loss)
  [20] VPS Bandwidth & Speedtest (Global & Regional Throughput)
  [21] Live Connections & Traffic Monitor (Real-time MB/s & Clients)
  [22] Port & Firewall Doctor (Scan ports & One-Click Port Opener)
  [23] Recommended VLESS-Reality Setup on Free Port 443

  --- [ MANAGEMENT ] ---
  [r]  Restore / Rollback Settings to Original State
  [u]  Update Omega Suite to Latest Release
  [0]  Exit
```

---

## 🔬 بررسی عمیق شاهکارهای فنی امگا

### ۱. سگ نگهبان هوشمند ۲۴/۷ پنل و هسته اشعه (`omega-watchdog.sh`) 🐕
- در صورت بروز کمبود حافظه یا حملات فیلترینگ که منجر به توقف ناگهانی پنل ۳ایکس‌یوآی یا هسته Xray شود، سگ نگهبان در کمتر از ۳ ثانیه سرویس را بدون نیاز به حضور ادمین زنده می‌کند.
- تمام رخدادهای کراش در لاگ ذخیره شده و در صورت اتصال ربات تلگرام، هشدار فوری ارسال می‌شود.

### ۲. آنلاکر خودکار گوگل و چت‌جی‌پی‌تی (`omega-unban.sh`) 🤖🔓
- **چرا گوگل کپچا نشان می‌دهد؟** لینوکس به طور پیش‌فرض اولویت خروجی را به رنج‌های آلوده IPv6 دیتاسنترها می‌دهد.
- **راهکار خودکار امگا:** با تنظیم اولویت استاندارد IPv4 در `/etc/gai.conf` و روتشین اتوماتیک سشن‌های Cloudflare WARP، کپچای گوگل و بن چت‌جی‌پی‌تی را به صورت خودکار در پس‌زمینه رفع می‌کند.

### ۳. حل اختلال اپراتورهای سخت‌گیر (سامانتل، رایتل و شبکه سلولار) (`omega-operator-fix.sh`) 📶
- شبکه اپراتور سامانتل و برخی دکل‌های LTE به دلیل سربرگ‌های اضافی encapsulation پکت‌های بزرگتر از MTU را بدون ارسال پیام ICMP Fragmentation Needed رها می‌کنند (اصطلاحاً Path MTU Blackhole).
- امگا با اعمال قانون هوشمند `--clamp-mss-to-pmtu` در جدول `POSTROUTING`، سقف اندازه پکت‌های TCP را دقیقاً مطابق با سقف مجاز مسیر کلاینت تراز می‌کند و مشکل فریز شدن یا لود نشدن کانفیگ‌ها را ۱۰۰٪ روی سرور حل می‌کند.

### ۴. شتاب‌دهنده ویدیو و اینستاگرام سازگار با وارپ (`omega-instagram-fix.sh`) 📸
- برخلاف اسکریپت‌های سنتی که کل پورت UDP 443 را می‌بندند و باعث قطعی WireGuard و Cloudflare WARP می‌شوند، امگا لیست دقیق ساب‌نت‌های رسمی شرکت متا (ASN 32934 / Meta CIDRs) را در یک `ipset` سخت‌افزاری ایزوله می‌کند.
- فقط پروتکل مسدودشده QUIC در مسیر اینستاگرام به TCP پرسرعت هدایت می‌شود، در حالی که سرویس‌های گوگل، هوش مصنوعی، و WARP به حداکثر سرعت نامحدود دسترسی دارند.

### ۵. اسکنر هوشمند آی‌پی تمیز کلودفلر (`omega-cf-scanner.sh`) ☁️
- اسکن لحظه‌ای و اندازه‌گیری تأخیر (TCP Latency) روی رنج‌های طلایی کلودفلر برای اینباندهای WebSocket / CDN بدون نیاز به تغییر سرور.

### ۶. سیستم هشدار و مانیتورینگ زنده تلگرام (`omega-telegram.sh`) 📱
- اتصال مستقیم با توکن ربات تلگرام و Chat ID برای دریافت هشدار در هنگام ری‌استارت هسته، خطاهای امنیتی، و موفقیت بکاپ‌های دوره‌ای.

---

## 🔄 بازگردانی تغییرات به حالت اولیه (Rollback Guarantee)

شما در هر زمان می‌توانید با زدن کلید **`r`** در منوی اصلی، تمام قوانین شبکه، فایروال و تنظیمات کرنل را دقیقاً به حالت خام کارخانه سرور بازگردانید:

```bash
omega -> [r] Restore / Rollback Settings
```

---

## 🤝 لایسنس و حقوق استفاده

این پروژه تحت لایسنس MIT منتشر شده و توسعه آن برای کمک به جامعه ادمین‌های سرور و دسترسی به اینترنت آزاد و پرسرعت انجام گرفته است.  
توسعه‌یافته با ❤️ برای آزادی اطلاعات.
