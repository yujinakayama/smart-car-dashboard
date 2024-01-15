This is a work around to avoid `button` component name conflict;
Both esp-homekit-sdk and esp-idf-lib have `button` components,
and esp-idf picks only the last one.
Since we want to use esp-homekit-sdk's `button` component,
we use only neccessary components from esp-idf-lib (bmp280 and the dependencies)
instead of adding `esp-idf-lib/components` to EXTRA_COMPONENT_DIRS.

https://docs.espressif.com/projects/esp-idf/en/v4.3/esp32/api-guides/build-system.html#cmake-components-same-name
