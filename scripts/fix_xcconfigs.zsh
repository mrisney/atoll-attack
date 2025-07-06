#!/usr/bin/env zsh

IOS_FLUTTER_DIR="ios/Flutter"
mkdir -p $IOS_FLUTTER_DIR

# Each entry is “<CONFIG>:<suffix>”
for pair in Debug:debug Profile:profile Release:release; do
  cfg=${pair%%:*}        # e.g. “Debug”
  suffix=${pair#*:}      # e.g. “debug”
  file="$IOS_FLUTTER_DIR/$cfg.xcconfig"
  pods="Pods/Target Support Files/Pods-Runner/Pods-Runner.$suffix.xcconfig"
  line="#include \"$pods\""

  if [[ ! -f $file ]]; then
    echo "👉 creating $file"
    print -- $line > $file
  else
    # append it if it’s not already there
    if ! grep -qxF -- "$line" "$file"; then
      print -- $line >> $file
    fi
  fi
done

# now reinstall pods & rebuild
(
  cd ios
  pod install --repo-update
)
flutter clean
flutter run

