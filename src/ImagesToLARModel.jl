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
  
  noise_shape = 0
  try
    noise_shape = configuration["noise_shape"]
  catch
  end
  
  return configuration["inputDirectory"], configuration["outputDirectory"],
        configuration["bestImage"],
        configuration["nx"], configuration["ny"], configuration["nz"],
        DEBUG_LEVELS[configuration["DEBUG_LEVEL"]],
        parallelMerge, noise_shape

end

function convertImagesToLARModel(configurationFile)
  """
  Start conversion of a stack of images into a 3D model
  loading parameters from a JSON configuration file

  configurationFile: Path of the configuration file
  """
  inputDirectory, outputDirectory, bestImage, nx, ny, nz,
      DEBUG_LEVEL, parallelMerge, noise_shape = loadConfiguration(open(configurationFile))
  convertImagesToLARModel(inputDirectory, outputDirectory, bestImage,
                        nx, ny, nz, DEBUG_LEVEL, parallelMerge, noise_shape)
end

function convertImagesToLARModel(inputDirectory, outputDirectory, bestImage,
                                 nx, ny, nz, DEBUG_LEVEL = INFO,
                                 parallelMerge = false, noise_shape = 0)
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
  noise_shape: The shape for image denoising
  """
  # Create output directory
  try
    mkpath(outputDirectory)
  catch
  end

  Logging.configure(level=DEBUG_LEVEL)
  ImagesConversion.images2LARModel(nx, ny, nz, bestImage,
          inputDirectory, outputDirectory, parallelMerge, noise_shape)
end

end
