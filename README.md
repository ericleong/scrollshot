# scrollshot

A bash script for automatically scrolling and stitching screenshots of Android apps. Detects and accounts for overlapping pixels.

## requirements

* [bash](http://www.gnu.org/software/bash/) or a similar shell
* [imagemagick](http://www.imagemagick.org/script/index.php)

## api

```bash
$ scrollshot.sh <filename> <iterations> <footer keep> <footer ignore> <distance> <start> <overlap> <end>
```

| argument        | default    | purpose                                      |
| --------------- | ---------- | -------------------------------------------- |
| `filename`      | scrollshot | name of the output file, without `.png`      |
| `iterations`    | 3          | number of iterations to scroll               |
| `footer keep`   | auto       | bottom area to keep in output and ignore when scrolling (in pixels) |
| `footer ignore` | 0          | additional bottom area to ignore when scrolling (in pixels) |
| `distance`      | 2 * dpi    | distance to scroll per iteration (in pixels) |
| `start`         | -4dp       | initial overlap test offset (in pixels)      |
| `overlap`       | 20dp       | height of overlap test area (in pixels)      |
| `end`           | 4dp        | final overlap test offset (in pixels)        |

## tips

* Keep the [floating action button](https://www.google.com/design/spec/components/buttons-floating-action-button.html) from repeating with `footer ignore` set to about `78dp`.
* To preserve spacing in apps with a lot of whitespace (identical vertical pixels), increase `overlap`.
* Blinking cursors will fool the automatic footer detection.