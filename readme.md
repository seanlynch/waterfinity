# Waterminus

Finite liquids or modern Minetest.

## Physics

* *Source* liquid always tries to produce more flowing liquid.
* *Flowing* liquid tries to even out with its neighbours.
* Single-layer liquid runs towards holes up to 3 blocks away.
* Almost even liquid (1 layer difference) diffuses randomly if it is not nearly empty, so all bodies even out "eventually".

## Mod support

Custom buckets are supported with basic liquid pickup/place physics. Perfect liquid pointing will have to wait for 5.9.0 `pointabilities`.

## Usage

```
waterminus.register_liquid {
    source = "waterminus:spring",
    flowing = "waterminus:water",
    bucket = "waterminus:bucket_water"
    
    bucket_images = {
        "waterminus_bucket_water_part.png^waterminus_bucket_bar_1.png",
        "waterminus_bucket_water_part.png^waterminus_bucket_bar_2.png",
        "waterminus_bucket_water_part.png^waterminus_bucket_bar_3.png",
        "waterminus_bucket_water_part.png^waterminus_bucket_bar_4.png",
        "waterminus_bucket_water_part.png^waterminus_bucket_bar_5.png",
        "waterminus_bucket_water_part.png^waterminus_bucket_bar_6.png",
        "waterminus_bucket_water.png^waterminus_bucket_bar_7.png",
    }
}
```

* **source:** The 'spring' liquid. Infinite, always tries to produce more liquid, absorbs liquid from above. Optional.
* **flowing:** The main finite liquid.
* **bucket:** Optional. The prefix for bucket items to be registered for the liquid. E.G. "waterminus:bucket_water_1"
* **bucket_images:** A list of bucket item textures.