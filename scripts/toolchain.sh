# Sourced by build scripts. Pins the toolchain per invocation without
# touching global xcode-select; CI runners without Xcode-beta fall through
# to the system default.
if [[ -n "${PROBO_DEVELOPER_DIR:-}" ]]; then
  export DEVELOPER_DIR="$PROBO_DEVELOPER_DIR"
elif [[ -d "/Applications/Xcode-beta.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
fi
