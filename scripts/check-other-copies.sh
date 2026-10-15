#!/bin/sh
# Warns about Brow.app copies other than the installed one: Spotlight may open
# any of them, and an old copy looks like missing features.
# Usage: scripts/check-other-copies.sh /path/to/installed/Brow.app
installed="$1"
others=$(mdfind "kMDItemCFBundleIdentifier == 'com.freedrobili.Brow'" 2>/dev/null \
    | grep -v -x "$installed" | grep -v "\.noindex/")
[ -z "$others" ] && exit 0
echo ""
echo "⚠️  Найдены другие копии Brow. Spotlight может открыть их вместо новой версии:"
echo "$others" | sed 's/^/    /'
echo "   Если они не нужны, закройте Brow и переместите их в Корзину."
echo ""
