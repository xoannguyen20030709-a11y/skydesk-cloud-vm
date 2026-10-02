# ⚡ SkyDesk OS - Windows Server Cloud PC Automation & Web Remote Portal

<div align="center">

![SkyDesk Cloud PC Banner](https://img.shields.io/badge/SkyDesk%20OS-Cloud%20VM%20v2.0-indigo?style=for-the-badge&logo=windows&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Windows%20Latest-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)
![Vercel](https://img.shields.io/badge/Vercel-Deployed-black?style=for-the-badge&logo=vercel&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-emerald?style=for-the-badge)

**Máy Ảo Windows Server Miễn Phí & Cổng Quản Lý Web Remote Tự Động Hóa Dành Cho Học Sinh, Sinh Viên & Lập Trình Viên**

[✨ Dùng Thử Web Portal](#) • [🚀 Khởi Tạo 1-Click](#-hướng-dẫn-khởi-tạo-1-click) • [🌐 Web Remote](#-tính-năng-nổi-bật) • [📖 Tài Liệu API](#-tài-liệu-api)

</div>

---

## 🌟 Giới Thiệu (Overview)

**SkyDesk OS** là một giải pháp mã nguồn mở hoàn chỉnh, kết hợp sức mạnh của **GitHub Actions Free Runner (`windows-latest`)** và giao diện điều khiển **Next.js Web Portal (triển khai trên Vercel)**.

Hệ thống cho phép học sinh, sinh viên và những người không có máy tính cá nhân hoặc máy tính yếu có thể tạo ngay một chiếc **Cloud PC Windows Server** cấu hình cao trong vòng **1 đến 2 phút** chỉ với **1 cú click**, sau đó điều khiển trực tiếp trên trình duyệt web hoặc phần mềm Remote Desktop.

### 🖥️ Thông Số Kỹ Thuật Máy Ảo (Specifications)
- **Hệ Điều Hành:** Windows Server 2022 / 2025 Datacenter (x64)
- **Vi Xử Lý (CPU):** 4 vCPUs (Intel Xeon Platinum / AMD EPYC)
- **Bộ Nhớ (RAM):** 7 GB - 16 GB DDR4 High Speed
- **Ổ Cứng (SSD):** 256 GB NVMe SSD siêu tốc
- **Mạng:** Băng thông Gigabit ~1 Gbps đối xứng
- **Thời lượng phiên:** Tối đa **6 giờ liên tục / phiên** (Có thể khởi tạo lại không giới hạn lần)
- **Giao thức Remote:** RDP (Port 3389), In-Browser Web HTML5 Console, Cloudflare Zero-Trust Tunnels, Pinggy.io, Ngrok.

---

## 🚀 Hướng Dẫn Khởi Tạo 1-Click (Quickstart)

### Bước 1: Tạo GitHub Personal Access Token (PAT)
1. Truy cập [GitHub Token Settings](https://github.com/settings/tokens/new?scopes=repo,workflow&description=SkyDesk+Cloud+VM).
2. Tích chọn 2 quyền:
   - `repo` (Toàn quyền repository)
   - `workflow` (Quyền kích hoạt GitHub Actions workflow)
3. Nhấn **Generate token** và sao chép mã token (`ghp_...`).

### Bước 2: Khởi Tạo Trên Web Portal
1. Truy cập Web Portal của bạn trên Vercel.
2. Dán mã **PAT** vào ô **Xác Thực GitHub (PAT)**.
3. Nhấn **Fork / Check** để hệ thống tự động clone repo về tài khoản của bạn.
4. Chọn chế độ đường truyền (Multi-Tunnel / Cloudflare / Pinggy / Ngrok) và nhấn **"KÍCH HOẠT WORKFLOW TẠO VM NGAY"**.

### Bước 3: Lấy Token & Kết Nối Remote
1. Sau khi workflow chạy khoảng 1-2 phút, bạn sẽ nhận được mã **VM Access Token** (dạng `skydesk_vm_...`).
2. Dán mã Token vào tab **"Quản Lý VM (Token)"**:
   - Nhấn **"Mở Web Remote"** để điều khiển trực tiếp trên trình duyệt mà không cần cài đặt bất kỳ phần mềm nào!
   - Hoặc nhấn **"Tải File .RDP"** để mở bằng ứng dụng Microsoft Remote Desktop trên máy tính/điện thoại.

---

## 🛠️ Cấu Trúc Dự Án (Project Structure)

```text
├── .github/
│   └── workflows/
│       └── cloud_pc.yml        # GitHub Actions Workflow chạy trên windows-latest
├── scripts/
│   ├── setup_vm.ps1            # Kịch bản PowerShell cài đặt RDP, User, Tunnels & Web Gateway
│   └── keepalive.ps1          # Engine duy trì trạng thái hoạt động & theo dõi tài nguyên 6 giờ
├── src/
│   ├── app/
│   │   ├── api/
│   │   │   ├── github/         # API Fork, Dispatch Workflow, Tra cứu Run Status
│   │   │   ├── token/          # API Giải mã, Xác thực & Phát hành VM Session Token
│   │   │   └── rdp/            # API Xuất file cấu hình .RDP tùy chỉnh tức thì
│   │   ├── globals.css         # Cyberpunk/Glassmorphism Theme UI
│   │   ├── layout.tsx          # HTML Root & Metadata
│   │   └── page.tsx            # Giao diện chính điều khiển toàn bộ hệ thống
│   ├── components/
│   │   ├── Navbar.tsx          # Thanh điều hướng đa ngôn ngữ (VI/EN)
│   │   ├── LauncherTab.tsx     # Bảng khởi tạo VM bằng GitHub PAT & Live Tracker
│   │   ├── VMDashboardTab.tsx  # Bảng hiển thị thông số VM, Countdown Timer, Credentials
│   │   ├── WebRemoteViewer.tsx # Trình điều khiển Remote Desktop Web HTML5
│   │   ├── ToolsLibraryTab.tsx # Kho phần mềm 1-click cho lập trình viên & học sinh
│   │   └── DocsTab.tsx         # Tài liệu hướng dẫn chi tiết & API Reference
│   └── lib/
│       └── session.ts          # Thư viện xử lý mã hóa Token & RDP generator
├── vercel.json                 # Cấu hình triển khai tự động lên Vercel
├── package.json
└── README.md
```

---

## 🛡️ Cam Kết Sử Dụng Lành Mạnh (Educational Policy)

Dự án được xây dựng với mục tiêu cao đẹp: **Giúp đỡ học sinh, sinh viên và những người có hoàn cảnh khó khăn không có điều kiện sở hữu máy tính cá nhân cấu hình cao** có môi trường học tập lập trình (Python, Node.js, C/C++, Web, AI cơ bản).

- ❌ **Tuyệt đối nghiêm cấm:** Đào tiền ảo (Crypto Mining), phát tán mã độc (Malware), tấn công từ chối dịch vụ (DDoS/Botnet), Spam.
- ✅ **Khuyến khích:** Học tập lập trình, biên dịch mã nguồn, kiểm thử ứng dụng, làm bài tập tin học.

---

## 📄 Bản Quyền (License)

Dự án phát hành theo giấy phép [MIT License](LICENSE).
Tự do sử dụng, chỉnh sửa và đóng góp cho cộng đồng!
