# ImagesToLARModel.jl

Installation
------

    Pkg.clone("git://github.com/sadan91/ImagesToLARModel.jl.git")
    
This module require an installation of python with scipy and numpy for the denoising filter

Use
------

#### Data preparation

    using(ImagesToLARModel)
    prepareData(<JSON-configuration-file-path>)
 
 or:
 
    using(ImagesToLARModel)
    prepareData(<Input directory>, <Output directory> [, <crop>, <noise_shape>, <threshold>])

This is an example of a valid JSON configuration file:

    {
      "inputDirectory": "Path of the input directory",
      "outputDirectory": "Path of the output directory",
      "crop": List with values for images resizing (they can be extended or cropped),
      "noise_shape": A number which indicates the intensity of the denoising
                     filter (0 if you want to disable denoising),
      "threshold": A number indicating the chosen threshold for data
      "threshold3d": A number indicating the chosen threshold for the
                     three-dimensional filter (0 if you want to disable this filter)
      "zDim": A number indicating the number of images computed at once from the
              three-dimensional filter (0 if you want to take the entire stack)
    }
    
For example we can write:

    { 
        "inputDirectory": "/home/juser/IMAGES/",
        "outputDirectory": "/home/juser/OUTPUT/",
        "crop": [[1,800],[1,600],[1,50]],
        "noise_shape": 0,
        "threshold": 8,
        "threshold3d": 100,
        "zDim":0
    }

These are the accepted parameters:

- inputDirectory: Directory containing the stack of images
- outputDirectory: Directory containing the output
- crop: Parameter for images resizing (they can be extended or cropped)
- noise_shape: Intensity of the denoising filter for images (0 if you want to disable it)
- threshold: Set a threshold for raw data. Pixels under that threshold will be 
             set to black, otherwise they will be set to white. If threshold 
             is not specified, segmentation will be done using a clustering algorithm
- threshold3d: set a threshold for the three-dimensional filter
- zDim: set the number of images computed at once from the three-dimensional filter

#### Data conversion

    using(ImagesToLARModel)
    convertImagesToLARModel(<JSON-configuration-file-path>)
 
 or:
 
    using(ImagesToLARModel)
    convertImagesToLARModel(<Input directory>, <Output directory>, <Border x>, <Border y>, <Border z>[, <DEBUG_LEVEL>, <parallelMerge>])

This is an example of a valid JSON configuration file:

    {
      "inputDirectory": "Path of the input directory",
      "outputDirectory": "Path of the output directory",
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
        "nx": 2,
        "ny": 2,
        "nz": 2,
        "DEBUG_LEVEL": 2
    }

These are the accepted parameters:

- inputDirectory: Directory containing the stack of images
- outputDirectory: Directory containing the output
- nx, ny, nz: Border dimensions
- DEBUG_LEVEL: Debug level for [Julia logger](https://github.com/kmsquire/Logging.jl). It can be one of the following:
    - DEBUG (1 for JSON configuration file)
    - INFO (2 for JSON configuration file)
    - WARNING (3 for JSON configuration file)
    - ERROR (4 for JSON configuration file)
    - CRITICAL (5 for JSON configuration file)
- parallelMerge: Choose if you want to merge model files using a distribuite algorithm or not (experimental)
