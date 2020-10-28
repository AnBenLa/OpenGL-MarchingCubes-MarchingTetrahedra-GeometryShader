# Visualization Final Project

Marching Cubes and Marching Tetracubes using the geometry shader.
Voxel size, isovalue can be modified at runtime.
Simple LOD can be activated. Volumes up to 256x256x256 can be visualized.
Surface Shifting can be activated to reduce holes between differen LODs.
Transvoxel algorithm partially implemented.

Installation on Windows:
========================
It is recommended to use an IDE (CLion, Visual Studio, ...) but everything can be done without as well  

To use the Framework using Visual Studio or CLion you can follow [this](https://www.youtube.com/watch?v=AjvwygYQT1k&feature=youtu.be) video.  

**Requirements**:  
- [git](https://gitforwindows.org/)
- [cmake](https://cmake.org/download/)
- [make for windows](http://gnuwin32.sourceforge.net/packages/make.htm)  
- compiler and cmake generator i.e. [MinGW-w64](https://sourceforge.net/projects/mingw-w64/)  
  
**Note**: One way to install MinGW 64:
- install [MSYS2](https://www.msys2.org/)  
- open the newly installed MSYS2 Shell
- install MinGW 64 using the MSYS2 Shell  
```
pacman -S mingw-w64-x86_64-gcc
```  
- add the folder MSYS2_root/mingw64/bin (i.e. C:\msys64\mingw64\bin) to your PATH environment variable  
   
You can also follow this [tutorial](https://www.youtube.com/watch?v=f3Ion00p78M) to install MinGW 64.  
  
**Step 0**: open the windows console (cmd) and go into the folder where the project files should be saved
  
**Step 1**: clone the repository 
```
git clone --recursive https://github.com/AnBenLa/OpenGL-MarchingCubes-Tetrahedra
```  
**Note**: this will copy the necessary project files into the current directory.    
  
**Step 2**: create a build folder in the project folder
```
cd OpenGL-MarchingCubes-Tetrahedra
mkdir build
```  
**Step 3**: open cmake-gui:  
![Cmake](https://www.uni-weimar.de/~bexo5814/rrII/images/CMake-0.png) 
  
  select the source (C:\\..\OpenGL-MarchingCubes-Tetrahedra) and build folder (C:\\..\OpenGL-MarchingCubes-Tetrahedra\build)    
  click "generate" and select the cmake generator  
  (in this case MinGW Makefiles is chosen)  
  **Note**: make sure the environment variable for the generator is set  
  
  If the generation was successful it should look like this:  
  ![Cmake](https://www.uni-weimar.de/~bexo5814/rrII/images/CMake-1.png) 

**Step4**: go into the build folder and make the project  
```
cd build
make
```
If the make command was executed successfully it should look like this:  
  ![Make](https://www.uni-weimar.de/~bexo5814/rrII/images/Make.png)   
  
**Step 5**: execute the application:
```
.\main.exe
```

**Note**: If your project is build in a different folder you have to take care of the shader-paths  
  
  
Installation on Linux:
========================
It is recommended to use an IDE (CLion, Visual Studio, ...) but everything can be done without as well  

**Step 0:** open a terminal  
  
**Step 1**: install dependencies  
```
sudo apt-get update
sudo apt-get install git cmake libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev libglu1-mesa-dev
```

**Step 2**: clone the repository 
```
git clone --recursive https://github.com/AnBenLa/OpenGL-MarchingCubes-Tetrahedra
```

**Step 3**: create a build folder in the project folder
```
cd OpenGL-MarchingCubes-Tetrahedra
mkdir build
```
**Step 4**: inside the build folder generate the cmake project
```
cd build
cmake ..
```
**Step 5**: make the project and execute the application
```
make
./main
```  

Video:
========================
You can see the program in action [here](https://youtu.be/sEOOHrsOR8k)
