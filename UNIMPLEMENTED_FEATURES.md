# 🔍 Tính Năng Chưa Được Implement — Audit Toàn Diện

> **Audit**: 2026-04-10 | **Codebase**: `MovieStreamingApple`
>
> Tất cả các mục dưới đây hiện **chỉ có UI** nhưng **chưa có logic/backend thật**.
> Đã **comment out** toàn bộ để Apple Review không thấy tính năng giả.

---

## 🛡️ App Store Review — Trạng Thái Xử Lý

| # | Tính năng | Hành động | Trạng thái |
|---|-----------|-----------|------------|
| 1 | Nút "Đăng nhập" | ✅ Commented out, giữ text "Khách" | Đã ẩn |
| 2 | Section "Tài khoản" (2 rows) | ✅ Commented out toàn bộ section | Đã ẩn |
| 3 | Section "Thư viện" (3 rows) | ✅ Commented out toàn bộ section | Đã ẩn |
| 4 | Nút "Yêu thích" (Detail) | ✅ Commented out | Đã ẩn |
| 5 | User Rating Stars | ✅ Commented out + ẩn khi rating = 0 | Đã ẩn |
| 6 | Nút "ĐÁNH DẤU" (Bookmark) | ✅ Commented out | Đã ẩn |
| 7 | Tab "Đánh Giá" (Reviews) | ✅ Removed from availableTabs | Đã ẩn |
| 8 | Nút "Danh sách" (Player) | ✅ Commented out | Đã ẩn |
| 9 | Nút "Đánh giá" (Player) | ✅ Commented out | Đã ẩn |
| ✅ | Nút "Chia sẻ" (Share) | **HOẠT ĐỘNG** — UIActivityViewController | Giữ nguyên |
| ✅ | Rating trung bình (read-only) | **HOẠT ĐỘNG** — chỉ hiện khi API có data > 0 | Giữ nguyên |

> **Lưu ý quan trọng**: Tất cả code đều có marker `// MARK: [UNIMPLEMENTED]` để dễ tìm lại.
> Tìm nhanh: search `[UNIMPLEMENTED]` trong Xcode.

---

## 📊 Tổng Quan

| Mức độ | Số lượng | Mô tả |
|--------|----------|-------|
| 🔴 Critical | 7 | Tính năng người dùng thấy rõ, bấm vào không hoạt động |
| 🟡 Medium | 4 | Nút/UI hiện diện nhưng đã disabled, user biết "sắp ra mắt" |
| 🟢 Low | 4 | TODO trong code, chưa ảnh hưởng user experience trực tiếp |

---

## 🔴 1. Nút "Đăng nhập" (Profile Page)

- **File**: `ProfileView.swift` → `profileHeader`
- **Page**: Tab "Hồ sơ" → Header profile
- **Hiện trạng**: ~~Nút "Đăng nhập" hiển thị, bấm vào không có action~~
- **Đã xử lý**: ✅ **COMMENTED OUT** — Chỉ còn avatar + text "Khách"
- **Cần implement**: Hệ thống authentication (đăng nhập/đăng ký, OAuth, v.v.)

---

## 🔴 2. Mục "Thông tin cá nhân" (Profile Page)

- **File**: `ProfileView.swift` → Section "Tài khoản"
- **Page**: Tab "Hồ sơ" → Section "Tài khoản"
- **Hiện trạng**: ~~Row hiển thị "Thông tin cá nhân", `isDisabled: true`~~
- **Đã xử lý**: ✅ **COMMENTED OUT** — Toàn bộ section "Tài khoản" đã ẩn

---

## 🔴 3. Mục "Thông báo" (Profile Page)

- **File**: `ProfileView.swift` → Section "Tài khoản"
- **Page**: Tab "Hồ sơ" → Section "Tài khoản"
- **Hiện trạng**: ~~Row hiển thị "Thông báo", `isDisabled: true`~~
- **Đã xử lý**: ✅ **COMMENTED OUT** — Ẩn cùng section "Tài khoản"
- **Cần implement**: Push notification system, notification preferences

---

## 🔴 4. Mục "Lịch sử xem" (Profile Page — navigation)

- **File**: `ProfileView.swift` → Section "Thư viện"
- **Page**: Tab "Hồ sơ" → Section "Thư viện"
- **Hiện trạng**: ~~Row "Lịch sử xem" hiển thị nhưng `isDisabled: true`~~
- **Đã xử lý**: ✅ **COMMENTED OUT** — Toàn bộ section "Thư viện" đã ẩn
- **Lưu ý**: Dữ liệu lịch sử xem **đã có** (WatchHistoryManager hoạt động), chỉ thiếu navigate từ Profile

---

## 🔴 5. Mục "Yêu thích" (Profile Page)

- **File**: `ProfileView.swift` → Section "Thư viện"
- **Page**: Tab "Hồ sơ" → Section "Thư viện"
- **Hiện trạng**: ~~Row "Yêu thích", `isDisabled: true`~~
- **Đã xử lý**: ✅ **COMMENTED OUT** — Ẩn cùng section "Thư viện"
- **Cần implement**: Favorite system (lưu danh sách phim yêu thích, backend API hoặc local)

---

## 🔴 6. Mục "Tải xuống" (Profile Page)

- **File**: `ProfileView.swift` → Section "Thư viện"
- **Page**: Tab "Hồ sơ" → Section "Thư viện"
- **Hiện trạng**: ~~Row "Tải xuống", `isDisabled: true`~~
- **Đã xử lý**: ✅ **COMMENTED OUT** — Ẩn cùng section "Thư viện"
- **Cần implement**: Offline download system

---

## 🔴 7. Nút "Yêu thích" (Content Detail Page — Header)

- **File**: `DetailHeaderView.swift` → Actions row
- **Page**: Trang chi tiết phim → Action bar
- **Hiện trạng**: ~~Icon ❤️ + text "Yêu thích", opacity 0.5, không interactive~~
- **Đã xử lý**: ✅ **COMMENTED OUT** — Chỉ còn nút "Chia sẻ" (hoạt động)

---

## 🟡 8. Nút "ĐÁNH DẤU" / Bookmark (Content Detail — Poster)

- **File**: `DetailPosterView.swift`
- **Page**: Trang chi tiết phim → Dưới poster
- **Hiện trạng**: ~~Nút "ĐÁNH DẤU" hiển thị, `.disabled(true)`, opacity 0.5~~
- **Đã xử lý**: ✅ **COMMENTED OUT**

---

## 🟡 9. Đánh giá phim — Hiển thị Rating (Content Detail — Rating Section)

- **File**: `DetailHeaderView.swift` → Rating row
- **Page**: Trang chi tiết phim → Rating section

### Hai phần riêng biệt:

**a) Rating trung bình (read-only — từ API):**
- ✅ **HOẠT ĐỘNG** — Đây là data thật từ API, chỉ hiển thị, không cho user tương tác
- ✅ **ĐÃ SỬA**: Khi `averageRating = 0` hoặc `nil` → **ẩn hoàn toàn** section rating
- **Lý do**: Nếu hiện "0.0" + 5 sao trống + "Chưa có đánh giá" → user tưởng tính năng đánh giá hoạt động nhưng chưa ai rate

**🐛 BUG ĐÃ SỬA — Field Name Mismatch:**
- **List API** (`/contents?...`): trả `average_rating` + `rating_count` ở **top-level** → decode OK vào `Content.averageRating`
- **Detail API** (`/movie/{slug}`): trả `average_rating` + `rating_count` **chỉ trong `stats` object** → `Content.averageRating` = nil
- **Sửa 1**: Thêm `viewModel.averageRating` computed property → fallback `stats → top-level` (giống pattern `ratingCount` đã có)
- **Sửa 2**: `WatchDetailResponse.asContent` → `averageRating: averageRating ?? stats?.averageRating`
- **Sửa 3**: `DetailHeaderView` dùng `viewModel.averageRating` thay vì `content.averageRating`
- **Files đã sửa**: `ContentDetailViewModel.swift`, `DetailHeaderView.swift`, `APIClient.swift`

**b) User rating stars (cho user đánh giá):**
- ✅ **COMMENTED OUT** — Chưa có API submit rating
- ~~5 sao xám, text "Đánh giá phim:", opacity 0.5, không bấm được~~

---

## 🟡 10. Tab "Đánh Giá" (Reviews) + Nút "VIẾT ĐÁNH GIÁ"

- **File**: `DetailReviewsView.swift` (toàn bộ file), `ContentDetailViewModel.swift`
- **Page**: Trang chi tiết phim → Tab "Đánh Giá"
- **Hiện trạng**: ~~Tab hiện empty state "Chưa có đánh giá nào" + nút "VIẾT ĐÁNH GIÁ" disabled~~
- **Đã xử lý**: ✅ **Tab đã bị remove** khỏi `availableTabs` trong `ContentDetailViewModel.swift`
  - Series: `[.overview, .episodes, .cast]` (bỏ `.reviews`)
  - Movie: `[.overview, .cast]` (bỏ `.reviews`)
- **Cần implement**: API fetch reviews + submit review form

---

## 🟡 11. "Danh sách" + "Đánh giá" (Player Action Bar)

- **File**: `PlayerActionBar.swift`
- **Page**: Trang xem phim → Action bar dưới player
- **Hiện trạng**: ~~2 nút "Danh sách" + "Đánh giá" với `isComingSoon: true`~~
- **Đã xử lý**: ✅ **COMMENTED OUT** — Chỉ còn nút "Chia sẻ" (Share) + "Tập tiếp theo" (Next Episode)
- **Nút Chia sẻ**: ✅ **HOẠT ĐỘNG** — Mở UIActivityViewController, share link phim

---

## 🟢 12. Episode Title trong Watch History

- **File**: `WatchHistoryManager.swift` dòng 286
- **Hiện trạng**: Khi tạo `WatchDisplayData`, `episodeTitle` luôn = `nil`
- **Comment**: `// TODO: fetch from episodes API if needed`
- **Ảnh hưởng**: Cards trong "Đang Xem" hub chỉ hiển thị tên phim, không hiện tên tập
- **Không ảnh hưởng Apple Review** — UI không bị broken, chỉ thiếu thông tin bổ sung

---

## 🟢 13. Backend Suggested Skip Values (Skip Intro/Outro)

- **File**: `SkipContentSettings.swift` dòng 12–14, 51–66
- **File liên quan**: `PlayerSkipContentSheet.swift` dòng 113–124
- **Hiện trạng**:
  - `suggestedIntroDuration` và `suggestedOutroDuration` luôn = `nil`
  - UI hint "Gợi ý: ..." ready nhưng backend chưa gửi timestamps
  - User phải tự nhập thời gian skip thủ công
- **Lưu ý**: Skip feature **HOẠT ĐỘNG** — chỉ thiếu phần gợi ý tự động
- **Không ảnh hưởng Apple Review** — Tính năng hoạt động, chỉ thiếu enhancement

---

## 🟢 14. Sync Watch History với User Account

- **File**: `WatchHistoryManager.swift` dòng 9
- **Hiện trạng**: Lịch sử xem lưu **local bằng UserDefaults**, max 30 entries
- **Comment**: `// Future: Will sync with user account via API.`
- **Ảnh hưởng**: Nếu xoá app hoặc đổi thiết bị → mất toàn bộ lịch sử xem
- **Không ảnh hưởng Apple Review** — Tính năng local hoạt động hoàn chỉnh

---

## 🟢 15. Genre Navigation từ Trang Chi Tiết

- **File**: `DetailOverviewView.swift` dòng 121–135
- **Page**: Trang chi tiết phim → Tab "Tổng Quan" → Section "Thể loại"
- **Hiện trạng**: Genre badges hiển thị nhưng **không có tap action** — không navigate sang Browse
- **Lưu ý**: Router đã sẵn sàng, chỉ cần gắn navigation link
- **Không ảnh hưởng Apple Review** — Badges trông như label, không trông như nút

---

## 📋 Tóm Tắt Theo Page

### Tab "Hồ sơ" (Profile)
| # | Tính năng | Trạng thái ban đầu | Đã xử lý |
|---|-----------|---------------------|----------|
| 1 | Đăng nhập | 🔴 Nút bấm không action | ✅ Commented out |
| 2 | Thông tin cá nhân | 🔴 Row disabled | ✅ Commented out |
| 3 | Thông báo | 🔴 Row disabled | ✅ Commented out |
| 4 | Lịch sử xem (navigate) | 🔴 Row disabled | ✅ Commented out |
| 5 | Yêu thích | 🔴 Row disabled | ✅ Commented out |
| 6 | Tải xuống | 🔴 Row disabled | ✅ Commented out |

### Trang Chi Tiết Phim (Content Detail)
| # | Tính năng | Trạng thái ban đầu | Đã xử lý |
|---|-----------|---------------------|----------|
| 7 | Nút Yêu thích | 🔴 Disabled, opacity 0.5 | ✅ Commented out |
| 8 | Nút Đánh Dấu (Bookmark) | 🟡 Disabled | ✅ Commented out |
| 9a | Rating trung bình (read-only) | ✅ Hiện data từ API | ✅ Ẩn khi = 0 |
| 9b | User Rating Stars | 🟡 Không interactive | ✅ Commented out |
| 10 | Tab Reviews + Viết Đánh Giá | 🟡 Luôn empty | ✅ Tab removed |
| 15 | Genre chip navigation | 🟢 Không navigate | ⏸️ Giữ nguyên |

### Trang Xem Phim (Player)
| # | Tính năng | Trạng thái ban đầu | Đã xử lý |
|---|-----------|---------------------|----------|
| 11a | Nút Danh sách | 🟡 "Sắp ra mắt" | ✅ Commented out |
| 11b | Nút Đánh giá | 🟡 "Sắp ra mắt" | ✅ Commented out |
| — | Nút Chia sẻ (Share) | ✅ Hoạt động | ✅ Giữ nguyên |
| 13 | Backend skip suggestions | 🟢 Property nil | ⏸️ Giữ nguyên |

### Tab "Đang Xem" (Watching Hub)
| # | Tính năng | Trạng thái ban đầu | Đã xử lý |
|---|-----------|---------------------|----------|
| 12 | Episode title display | 🟢 Luôn nil | ⏸️ Giữ nguyên |
| 14 | Cloud sync history | 🟢 Chỉ local | ⏸️ Giữ nguyên |

---

## ✅ Tính Năng Đã Hoạt Động (Không cần sửa)

| Tính năng | Vị trí | Ghi chú |
|-----------|--------|---------|
| **Chia sẻ (Share)** | DetailHeaderView + PlayerActionBar | Dùng `UIActivityViewController`, share link phim |
| **Rating trung bình** | DetailHeaderView + PlayerContentInfo | Read-only từ API; ẩn khi `averageRating ≤ 0` |
| **Skip Intro/Outro** | Player Settings | Hoạt động với preset + custom input |
| **Lịch sử xem** | WatchingHubView | Data local, UI đầy đủ |
| **Tìm kiếm & Lọc** | BrowseView + BrowseFilterSheet | API-backed, hoạt động |
| **Chọn giao diện** | ProfileThemePicker | 5 theme, persist qua @AppStorage |
