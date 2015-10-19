# TODOs

## ImagesToLARModel

- Because of a bug in ImageMagick probably it would be better to create a bash script for convert dicom images to png (convert -define dcm:display-range=reset slice.0000.0002.dcm -normalize slice.0000.0002.png). Oppure prova (convert -define dcm:display-range=reset slice.0000.0002.dcm -auto-level slice.0000.0002.png)

## PngStack2Array3dJulia

- Actually if images dimensions are odd I remove one pixel; perhaps it would be better to add one instead

## LARUtils

## GenerateBorderMatrix

- Border Matrix Generation needs to be parallelized

## ImagesConvertion

## Lar2Julia

- Convert all python functions inside larcc module into julia functions
- Delete all old pyplasm functions

## Model2Obj

- When creating stl files we need all cubes or only "+1" oriented faces?
- Final model creation is too slow; it needs to be parallelized

## Tests

- Update all old tests (they don't work after package refactoring)
- Add new tests for:
  - PngStack2Array3dJulia
  - LARUtils
  - GenerateBorderMatrix
  - Lar2Julia
  - Model2Obj
