# Turns the app options into NAME=value entries (NUL separated) for every mapped option that has
# a value. The mapping comes in as $map (the text of option-env.map).
#
# `false` is a real value, so only null and the empty string count as "not set".
. as $options
| ($map
    | split("\n")
    | map(select(length > 0 and (startswith("#") | not)) | split("=") | {path: .[0], name: .[1]}))
| .[]
| . as $entry
| ($options | getpath($entry.path | split(".")))
| select(. != null and . != "")
| "\($entry.name)=\(tostring)\u0000"
