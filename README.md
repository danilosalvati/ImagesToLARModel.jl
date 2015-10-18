# ImagesToLARModel.jl

Installation
------

    Pkg.clone("git://github.com/sadan91/ImagesToLARModel.jl.git")


Use
------

    using(ImagesToLARModel)
    convertImagesToLARModel(<JSON-configuration-file-path>)
 
 or:
 
    using(ImagesToLARModel)
    convertImagesToLARModel(<Input directory>, <Output directory>, <BestImage>, <Border x>, <Border y>, <Border z>[, <DEBUG_LEVEL>])

This is an example of a valid JSON configuration file:

    {
      "inputDirectory": "Path of the input directory",
      "outputDirectory": "Path of the output directory",
      "bestImage": "Name of the best image (with extension) ",
      "nx": border x,
      "ny": border x,
      "nz": border x,
      "DEBUG_LEVEL": julia Logging level
    }

These are the accepted parameters:

- inputDirectory: Directory containing the stack of images
- outputDirectory: Directory containing the output
- bestImage: Image chosen for centroids computation
- nx, ny, nz: Border dimensions (Possibly the biggest power of two of images dimensions)
- DEBUG_LEVEL: Debug level for [Julia logger](https://github.com/kmsquire/Logging.jl). It can be one of the following:
    - DEBUG (1 for JSON configuration file)
    - INFO (2 for JSON configuration file)
    - WARNING (3 for JSON configuration file)
    - ERROR (4 for JSON configuration file)
    - CRITICAL (5 for JSON configuration file)
