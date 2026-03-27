#!/bin/bash

# NexCoreProxy Agent 编译脚本

VERSION=$(cat ../VERSION 2>/dev/null || echo "v1.0.0")
BINARY_NAME="ncp-agent"

echo "编译 NexCoreProxy Agent $VERSION"

# 初始化模块
go mod tidy

# 编译多平台版本
PLATFORMS=(
    "linux/amd64"
    "linux/arm64"
    "linux/386"
)

for PLATFORM in "${PLATFORMS[@]}"; do
    IFS='/' read -r GOOS GOARCH <<< "$PLATFORM"
    OUTPUT_DIR="../bin/${GOOS}-${GOARCH}"
    mkdir -p "$OUTPUT_DIR"
    
    echo "编译 ${GOOS}/${GOARCH}..."
    GOOS=$GOOS GOARCH=$GOARCH CGO_ENABLED=0 go build -ldflags="-s -w" -o "$OUTPUT_DIR/$BINARY_NAME" .
done

echo ""
echo "编译完成!"
echo ""
ls -la ../bin/