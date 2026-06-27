#!/usr/bin/env bash
#
# build_release.sh — 构建 QuickLUT 的 Universal Binary（arm64 + x86_64）并打包成 .dmg
#
#   最低支持系统：macOS 13.0（由项目的 MACOSX_DEPLOYMENT_TARGET 决定）
#   签名方式：    Ad-hoc（codesign -s -），他人首次打开需在
#                 「系统设置 → 隐私与安全性」点「仍要打开」
#   依赖：        仅系统自带工具（xcodebuild / codesign / hdiutil / lipo），无外部依赖
#
#   用法：
#     ./build_release.sh            # 版本号自动从 pbxproj 的 MARKETING_VERSION 读取
#     ./build_release.sh 1.2.0      # 手动指定版本号（用于 dmg 命名）
#
set -euo pipefail

# ----------------------------- 配置 -----------------------------
PROJECT="QuickLUT.xcodeproj"
SCHEME="QuickLUT"
CONFIGURATION="Release"
APP_NAME="QuickLUT"

# 切到脚本所在目录（项目根目录）
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# 版本号：优先用第一个参数，否则从 pbxproj 读 MARKETING_VERSION
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    VERSION="$(grep -m1 'MARKETING_VERSION' "$PROJECT/project.pbxproj" \
               | sed -E 's/.*= *"?([^";]+)"?;.*/\1/' | tr -d '[:space:]')"
    [[ -z "$VERSION" ]] && VERSION="1.0"
fi

# 产物路径
BUILD_DIR="$ROOT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
DIST_DIR="$BUILD_DIR/dist"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION-universal.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

# ----------------------------- 工具函数 -----------------------------
log()  { printf "\033[1;34m▸ %s\033[0m\n" "$*"; }
ok()   { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }
die()  { printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

# ----------------------------- 前置检查 -----------------------------
command -v xcodebuild >/dev/null || die "未找到 xcodebuild，请先安装 Xcode"
command -v hdiutil    >/dev/null || die "未找到 hdiutil（应为系统自带）"
command -v lipo       >/dev/null || die "未找到 lipo（应为系统自带）"
[[ -d "$PROJECT" ]] || die "未找到 $PROJECT，请在项目根目录运行本脚本"

# ----------------------------- 0. 清理 -----------------------------
log "清理旧产物..."
rm -rf "$DERIVED_DATA" "$DIST_DIR"
mkdir -p "$DIST_DIR"

# ----------------------------- 1. 构建 Universal Binary -----------------------------
# 关键参数：
#   ARCHS="arm64 x86_64"  构建两种架构并合并为单一二进制（universal/fat）
#   ONLY_ACTIVE_ARCH=NO   关闭「只编当前架构」，否则在 arm64 机器上只会出 arm64
#   CODE_SIGNING_ALLOWED=NO 构建阶段不签名，统一在下面手动 ad-hoc 签（跨架构签名更可控）
log "构建 Universal Binary (arm64 + x86_64)，配置 $CONFIGURATION..."
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

[[ -d "$APP_PATH" ]] || die "构建完成但未找到 .app：$APP_PATH"
ok "构建完成：$APP_PATH"

# ----------------------------- 2. 验证双架构 -----------------------------
log "验证二进制架构..."
EXEC_PATH="$APP_PATH/Contents/MacOS/$APP_NAME"
ARCHS_BUILT="$(lipo -archs "$EXEC_PATH")"
echo "  $APP_NAME 架构：$ARCHS_BUILT"
echo "$ARCHS_BUILT" | grep -q 'x86_64' || die "缺少 x86_64 架构（AMD64）"
echo "$ARCHS_BUILT" | grep -q 'arm64'  || die "缺少 arm64 架构"
ok "双架构齐全"

# ----------------------------- 3. Ad-hoc 签名 -----------------------------
# QuickLUT 无嵌入框架，直接签外层即可；--deep 兜底以防将来加入 helper/资源
log "Ad-hoc 签名..."
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --verbose "$APP_PATH" 2>&1 | sed 's/^/  /' || die "签名验证失败"
ok "签名完成"

# ----------------------------- 4. 打包 .dmg -----------------------------
# 打成一个带 /Applications 软链接的压缩 dmg：用户可拖拽安装
log "打包 .dmg（含 /Applications 拖拽链接）..."
STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    "$DMG_PATH" >/dev/null

rm -rf "$STAGING"
[[ -f "$DMG_PATH" ]] || die "dmg 未生成：$DMG_PATH"

# ----------------------------- 5. 完成 -----------------------------
SIZE="$(du -h "$DMG_PATH" | awk '{print $1}')"
echo ""
ok "打包完成！"
echo "  产物：${DMG_PATH}"
echo "  大小：${SIZE}"
echo "  版本：${VERSION}（universal：arm64 + x86_64，最低 macOS 13.0）"
echo ""
echo "  分发提示：Ad-hoc 签名，他人首次打开会被 Gatekeeper 拦截，"
echo "           需在「系统设置 → 隐私与安全性」点「仍要打开」。"
