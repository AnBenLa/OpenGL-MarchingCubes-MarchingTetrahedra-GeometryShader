# Projects Settings
cmake_minimum_required (VERSION 3.1)
project (marching-cubes-tetrahedra)

file(GLOB_RECURSE FRAMEWORK_HEADERS  include/*.hpp include/*.h include/ImGui/*.hpp include/ImGui/*.h)
file(GLOB_RECURSE FRAMEWORK_SOURCES  source/*.cpp source/*.c   source/ImGui/*.cpp source/ImGui/*.c)

# The main executable
add_executable(main
        ${FRAMEWORK_SOURCES}
        ${FRAMEWORK_HEADERS}
)

set_property(TARGET main PROPERTY CXX_STANDARD 11)
target_compile_options(main PRIVATE -Wall)

# glfw
add_subdirectory(external/glfw EXCLUDE_FROM_ALL)
target_link_libraries(main PRIVATE glfw)

# glew
add_definitions(-DGLEW_STATIC)
add_subdirectory(external/glew-cmake EXCLUDE_FROM_ALL)
target_link_libraries(main PRIVATE libglew_static)

# glm
add_subdirectory(external/glm EXCLUDE_FROM_ALL)
target_link_libraries(main PRIVATE glm)
