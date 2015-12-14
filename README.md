# ImagesToLARModel.jl

Installation
------

    Pkg.clone("git://github.com/sadan91/ImagesToLARModel.jl.git")
    
This module require an installation of python with scipy and numpy

Use
------

#### Data preparation

    using(ImagesToLARModel)
    prepareData(<JSON-configuration-file-path>)
 
 or:
 
    using(ImagesToLARModel)
    prepareData(<Input directory>, <Output directory> [, <crop>, <noise_shape>])

This is an example of a valid JSON configuration file:

    {
      "inputDirectory": "Path of the input directory",
      "outputDirectory": "Path of the output directory",
      "crop": List with values for images resizing (they can be extended or cropped),
      "noise_shape": A number which indicates the intensity of the denoising
                     filter (0 if you want to disable denoising)
    }
    
For example we can write:

    { 
        "inputDirectory": "/home/juser/IMAGES/",
        "outputDirectory": "/home/juser/OUTPUT/",
        "crop": [[1,800],[1,600],[1,50]],
        "noise_shape": 0
    }

These are the accepted parameters:

- inputDirectory: Directory containing the stack of images
- outputDirectory: Directory containing the output
- crop: Parameter for images resizing (they can be extended or cropped)
- noise_shape: Intensity of the denoising filter for images (0 if you want to disable it)

#### Data conversion

    using(ImagesToLARModel)
    convertImagesToLARModel(<JSON-configuration-file-path>)
 
 or:
 
    using(ImagesToLARModel)
    convertImagesToLARModel(<Input directory>, <Output directory>, <BestImage>, <Border x>, <Border y>, <Border z>[, <DEBUG_LEVEL>, <parallelMerge>, <noise_shape>])

This is an example of a valid JSON configuration file:

    {
      "inputDirectory": "Path of the input directory",
      "outputDirectory": "Path of the output directory",
      "bestImage": "Name of the best image (with extension) ",
      "nx": border x,
      "ny": border y,
      "nz": border z,
      "DEBUG_LEVEL": julia Logging level
      "parallelMerge": "true" or "false",
    }
    
For example we can write:

    {
        "inputDirectory": "/home/juser/IMAGES/",
        "outputDirectory": "/home/juser/OUTPUT/",
        "bestImage": "0009.tiff",
        "nx": 2,
        "ny": 2,
        "nz": 2,
        "DEBUG_LEVEL": 2
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
- parallelMerge: Choose if you want to merge model files using a distribuite algorithm or not (experimental)
