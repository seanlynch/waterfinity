# Waterminus

Finite liquid physics for modern Minetest.

## Physics

* *Source* liquid always tries to produce more flowing liquid.
* *Flowing* liquid evens out with its neighbours.
* Thin liquid runs towards holes up to N blocks away.
* Almost even liquid (1 layer difference) jitters randomly if it is not nearly empty, so all bodies even out "eventually".

## Mod support

* `default`: Finite water and lava replace the 'regular' variants in generation.
* `buckets`: Custom buckets are supported with basic liquid pickup/place logic. Proper liquid pointing will be available with MT 5.9.0.
* `mesecons`: Pistons can push into liquids and compress them against blocks. (WIP)

## API

```
waterminus.register_liquid {
    source = "waterminus:spring",
    flowing = "waterminus:water",
    
    drain_range = 3,
    jitter = true,
    
    bucket = "waterminus:bucket_water",
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

* `source`: The node for the 'spring' liquid. Infinite, always tries to produce more liquid, absorbs liquid from above. Optional.
* `flowing`: The node for the finite liquid.
* `drain_range`: Optional, defaults to 3. How far thin liquid will run towards holes.
* `jitter`: Defaults to true. Whether almost even liquid will jitter randomly.
* `bucket`: Optional. The prefix for bucket items to be registered for the liquid. E.G. "waterminus:bucket_water_1"
* `bucket_images`: A list of bucket item textures.