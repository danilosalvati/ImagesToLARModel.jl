module ImagesToLARModel

push!(LOAD_PATH, Pkg.dir("ImagesToLARModel/src"))


import JSON
import ImagesConversion
import PngStack2Array3dJulia

using Logging

export convertImagesToLARModel, prepareData


function loadConfiguration(configurationFile)
  """
  load parameters from JSON file

  configurationFile: Path of the configuration file
  """

  configuration = JSON.parse(configurationFile)

  DEBUG_LEVELS = [DEBUG, INFO, WARNING, ERROR, CRITICAL]

  parallelMerge = false
  try
    if configuration["parallelMerge"] == "true"
      parallelMerge = true
    else
      parallelMerge = false
    end
  catch
  end
   
  return configuration["inputDirectory"], configuration["outputDirectory"],
        configuration["bestImage"],
        configuration["nx"], configuration["ny"], configuration["nz"],
        DEBUG_LEVELS[configuration["DEBUG_LEVEL"]],
        parallelMerge

end

function loadConfigurationPrepareData(configurationFile)
  """
  load parameters from JSON file for data preparation

  configurationFile: Path of the configuration file
  """

  configuration = JSON.parse(configurationFile)


  crop = Void
  try
    crop = configuration["crop"]
  catch
  end
  
  noise_shape = 0
  try
    noise_shape = configuration["noise_shape"]
  catch
  end
  
  threshold = Void
  try
    threshold = configuration["threshold"]
  catch
  end
  
  return configuration["inputDirectory"], configuration["outputDirectory"],
        crop, noise_shape, threshold

end

function prepareData(configurationFile)
  """
  Prepare the input data converting all files into png
  format with the desired resizing and denoising

  configurationFile: Path of the configuration file
  """
  inputPath, outputPath, crop,
          noise_shape, threshold = loadConfigurationPrepareData(open(configurationFile))

  prepareData(inputPath, outputPath, crop, noise_shape, threshold)
      
end

function prepareData(inputPath, outputPath,
                       crop = Void, noise_shape = 0, threshold = Void)
  """
  Prepare the input data converting all files into png
  format with the desired resizing and denoising

  inputPath: Directory containing the stack of images
  outputPath: Directory which will contain the output
  crop: Parameter for images resizing (they can be
        extended or cropped)
  noise_shape: The shape for image denoising
  threshold: Threshold for the raw data. All pixels under it
             will we set to black, otherwise they will be set to white
  """
  # Create output directory
  try
    mkpath(outputPath)
  catch
  end

  PngStack2Array3dJulia.convertImages(inputPath, outputPath, crop, noise_shape, threshold)
end

function convertImagesToLARModel(configurationFile)
  """
  Start conversion of a stack of images into a 3D model
  loading parameters from a JSON configuration file

  configurationFile: Path of the configuration file
  """
  inputDirectory, outputDirectory, bestImage, nx, ny, nz,
      DEBUG_LEVEL, parallelMerge = loadConfiguration(open(configurationFile))
  convertImagesToLARModel(inputDirectory, outputDirectory, bestImage,
                        nx, ny, nz, DEBUG_LEVEL, parallelMerge)
end

function convertImagesToLARModel(inputDirectory, outputDirectory, bestImage,
                                 nx, ny, nz, DEBUG_LEVEL = INFO,
                                 parallelMerge = false)
  """
  Start conversion of a stack of images into a 3D model

  inputDirectory: Directory containing the stack of images
  outputDirectory: Directory containing the output
  bestImage: Image chosen for centroids computation
  nx, ny, nz: Border dimensions (Possibly the biggest power of two of images dimensions)
  DEBUG_LEVEL: Debug level for Julia logger. It can be one of the following:
    - DEBUG
    - INFO
    - WARNING
    - ERROR
    - CRITICAL
  parallelMerge: Choose if you want to use the algorithm
  for parallel merging (experimental)
  """
  # Create output directory
  try
    mkpath(outputDirectory)
  catch
  end

  Logging.configure(level=DEBUG_LEVEL)
  ImagesConversion.images2LARModel(nx, ny, nz, bestImage,
          inputDirectory, outputDirectory, parallelMerge)
end

end
