#!/usr/bin/env bash
# ============================================================================
# 저장장치 한 줄 요약 — 제품명 · 용량 · 인터페이스 · 링크 대역폭
#
#   APPLE SSD AP1024Z · 932G · NVMe
#   Samsung SSD 990 PRO 2TB · 1.8T · NVMe PCIe 4.0 x4 (~7.9 GB/s)
#
# fastfetch 로그인 스플래시가 command 모듈로 이 스크립트를 부른다.
# 단독 실행도 된다: ~/.config/fastfetch/ssd-info.sh
#
# "읽기/쓰기 속도"에 대하여:
#   장치가 자기 실측 속도를 알려주는 인터페이스는 없다. 카탈로그의 "7,450MB/s"
#   같은 값은 제조사 마케팅 수치이지 조회 가능한 필드가 아니다. 그래서 여기서는
#   하드웨어가 실제로 보장하는 상한 — PCIe 링크 대역폭(세대 x 레인 수) — 을 찍는다.
#   실측이 필요하면 fio로 재야 한다 (README 아래쪽 참고).
#
# 하드웨어 정보는 안 바뀌므로 캐시한다 — 새 터미널마다 system_profiler(0.2초)를
# 돌리면 셸 시작이 그만큼 늦어진다. 캐시는 7일 뒤 또는 -r 로 갱신.
#
# mac 기본 bash 3.2에서도 도는 문법만 쓴다 (연관배열 금지).
# ============================================================================

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/ssd-info"
MAX_AGE_DAYS=7

[ "${1:-}" = "-r" ] && rm -f "$CACHE"

# 캐시가 있고 충분히 최신이면 그걸 쓴다
if [ -f "$CACHE" ] && [ -z "$(find "$CACHE" -mtime +$MAX_AGE_DAYS 2>/dev/null)" ]; then
    cat "$CACHE"
    exit 0
fi

# PCIe 링크 -> 대역폭. GT/s는 세대별로 정해져 있고 레인당 실효 대역폭도 고정이다
# (gen3부터 128b/130b 인코딩이라 GT/s의 약 98.5%가 데이터).
pcie_bw() {  # $1=GT/s 숫자  $2=레인 수  -> "PCIe 4.0 x4 (~7.9 GB/s)"
    local gts=$1 lanes=$2 gen per
    case "$gts" in
        2.5)  gen="1.0"; per=250 ;;
        5|5.0)   gen="2.0"; per=500 ;;
        8|8.0)   gen="3.0"; per=985 ;;
        16|16.0) gen="4.0"; per=1969 ;;
        32|32.0) gen="5.0"; per=3938 ;;
        64|64.0) gen="6.0"; per=7563 ;;
        *)    gen=""; per=0 ;;
    esac
    if [ -n "$gen" ] && [ "$lanes" -gt 0 ] 2>/dev/null; then
        # MB/s -> GB/s 소수 한 자리 (bc 없이 정수 연산으로)
        local tot=$(( per * lanes )) whole frac
        whole=$(( tot / 1000 )); frac=$(( (tot % 1000) / 100 ))
        printf 'PCIe %s x%s (~%s.%s GB/s)' "$gen" "$lanes" "$whole" "$frac"
    else
        printf 'PCIe x%s' "$lanes"
    fi
}

collect_mac() {
    # Apple Silicon의 내장 SSD는 커스텀 컨트롤러라 PCIe 링크 정보를 노출하지 않는다.
    # 얻을 수 있는 건 모델명/용량/NVMe 여부까지다.
    system_profiler SPNVMeDataType 2>/dev/null | awk '
        /^ +Model: /            { model = $0; sub(/^ +Model: /, "", model) }
        /^ +Capacity: /         { if (cap == "") { cap = $2 " " $3 } }
        /^ +TRIM Support: /     { trim = $3 }
        END {
            if (model != "") {
                line = model " · " cap " · NVMe"
                if (trim == "Yes") line = line " · TRIM"
                print line
            }
        }'
}

field() {  # $1=키 $2=lsblk -P 한 줄  -> 값 (없으면 빈 문자열)
    printf '%s' "$2" | sed -n "s/.*[[:space:]]*$1=\"\([^\"]*\)\".*/\1/p"
}

collect_linux() {
    # -P(키="값") 형식으로 받는다. 공백 구분으로 읽으면 MODEL이나 TRAN이 빈 장치에서
    # 열이 밀려 용량 자리에 모델명이 들어온다 (RAID 볼륨에서 실제로 겪음).
    lsblk -dn -P -o NAME,MODEL,SIZE,ROTA,TRAN 2>/dev/null | while read -r row; do
        name=$(field NAME "$row")
        case "$name" in loop*|zram*|sr*|ram*|"") continue ;; esac
        # lsblk는 모델명을 고정폭으로 패딩해서 준다 — 꼬리 공백을 떼야 " · "가 안 벌어진다
        model=$(field MODEL "$row" | sed 's/[[:space:]]*$//')
        size=$(field SIZE "$row")
        rota=$(field ROTA "$row")
        tran=$(field TRAN "$row")
        # lsblk가 모델을 못 주면 sysfs를 직접 본다 (RAID/가상 장치에서 흔하다)
        [ -n "$model" ] || model=$(cat "/sys/block/$name/device/model" 2>/dev/null | sed 's/ *$//')
        [ -n "$model" ] || model="$name"

        # 회전 디스크면 SSD가 아니다 — 그대로 밝힌다
        kind="SSD"; [ "$rota" = "1" ] && kind="HDD"

        iface=""
        case "$tran" in
            nvme)
                # /sys/class/nvme/nvme0/device 가 PCIe 장치 — 협상된 링크 속도/폭
                ctrl="/sys/class/nvme/${name%%n*}"
                spd=$(cat "$ctrl/device/current_link_speed" 2>/dev/null)
                wid=$(cat "$ctrl/device/current_link_width" 2>/dev/null)
                gts=$(printf '%s' "$spd" | awk '{print $1}')
                if [ -n "$gts" ] && [ -n "$wid" ]; then
                    iface="NVMe $(pcie_bw "$gts" "$wid")"
                else
                    iface="NVMe"
                fi
                ;;
            sata)
                # 협상된 SATA 세대 (1.5/3.0/6.0 Gbps)
                spd=$(cat /sys/class/ata_link/*/sata_spd 2>/dev/null | head -1)
                iface="SATA${spd:+ $spd}"
                ;;
            usb) iface="USB" ;;
            "")  iface="" ;;
            *)   iface=$(printf '%s' "$tran" | tr 'a-z' 'A-Z') ;;
        esac

        line="$model · $size · $kind"
        [ -n "$iface" ] && line="$model · $size · $iface"
        printf '%s\n' "$line"
    done
}

case "$(uname -s)" in
    Darwin) out=$(collect_mac) ;;
    Linux)  out=$(collect_linux) ;;
    *)      out="" ;;
esac

[ -n "$out" ] || out="(저장장치 정보 조회 실패)"
mkdir -p "$(dirname "$CACHE")"
printf '%s\n' "$out" > "$CACHE"
printf '%s\n' "$out"
