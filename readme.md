# Waterminus

Finite water flow for modern Minetest

## Physics

* *Source* water always tries to produce more flowing water.
* *Flowing* water tries to even out.
* Single-layer water runs towards holes up to 3 blocks away.
* Almost even water (1 layer difference) diffuses randomly if it is not nearly empty, so all bodies of water even out "eventually".

## Usage

```
waterminus.register_liquid {
    source = "waterminus:spring",
    flowing = "waterminus:water",
    bucket = "waterminus:bucket_water",
    bucket_image = "waterminus_bucket_water"
}
```

* **source:** The 'spring' liquid. Infinite, always tries to produce more liquid, absorbs liquid from above. Optional.
* **flowing:** The main finite liquid.
* **bucket:** Optional. The prefix for bucket items to be registered for the liquid. E.G. "waterminus:bucket_water_1"
* **bucket_image:** The prefix for bucket item textures. E.G. "waterminus_bucket_water_1.png"