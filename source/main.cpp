#define STB_IMAGE_IMPLEMENTATION

#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

#include <stdexcept>
#include <iostream>
#include <algorithm>
#include <map>
#include <set>

#include "../include/ImGui/imgui.h"
#include "../include/ImGui/imgui_impl_glfw.h"
#include "../include/ImGui/imgui_impl_opengl3.h"

#include "../include/shader.h"
#include "../include/camera.h"
#include "../include/transvoxel.h"
#include "../include/marching_cubes.h"

int width = 800, height = 600, current_mode = 1;
float last_x, last_y, delta_time = 0.0f, last_frame_time = 0.0f, current_iso_value = 0.2, current_voxel_size = 1.0f;
unsigned short x_dim = 32, y_dim = 32, z_dim = 32;
bool wireframe = false, first_mouse = false, show_voxels = false, sample = false, surface_shift = false, project_transvoxel = false;
std::vector<glm::vec3> points;
Camera *camera = new Camera{glm::vec3{0, 0, 1}, glm::vec3{0, 1, 0}};
GLuint volume_texture_id, edge_table_texture_id, triangle_table_texture_id, VBO, VAO, lod = 0;
GLuint cell_class_id, cell_data_id, regular_vertex_data_id, transition_cell_class_id, transition_cell_data_id, transition_vertex_data_id;
GLFWwindow *window;
Shader* marching_cubes_shader;
Shader* marching_tetracubes_shader;
Shader* marching_cubes_transvoxel_shader;
Shader* selected_shader;
Shader* cube_shader;

void key_callback(GLFWwindow *window, int key, int scancode, int action, int mods);

void mouse_callback(GLFWwindow *window, double x, double y);

void framebuffer_size_callback(GLFWwindow *window, int width, int height);

void uploadMatrices(GLuint shader);

void initialize();

void draw_imgui_windows();

void generate_table_textures();

void load_raw_volume(const char* raw_volume_path, unsigned short x_dim, unsigned short y_dim, unsigned short z_dim);

void compute_voxel_points(unsigned short x_dim, unsigned short y_dim, unsigned short z_dim, float voxel_size);

void upload_iso_value_and_voxel_size(GLuint shader);

void upload_lights_and_position(GLuint shader);

int main(int argc, const char *argv[]) {

    initialize();

    marching_cubes_shader = new Shader{"../shader/base.vert", "../shader/base.frag", "../shader/marching_cubes.geom"};
    marching_tetracubes_shader = new Shader{"../shader/base.vert", "../shader/base.frag", "../shader/marching_tetracubes.geom"};
    marching_cubes_transvoxel_shader = new Shader{"../shader/base.vert", "../shader/base.frag", "../shader/transvoxel.geom"};
    cube_shader = new Shader{"../shader/base.vert", "../shader/base.frag", "../shader/cube.geom"};

    selected_shader = marching_cubes_shader;

    load_raw_volume("../volume_files/bucky.raw", x_dim, y_dim, z_dim);

    generate_table_textures();

    compute_voxel_points(x_dim, y_dim, z_dim, current_voxel_size);

    upload_lights_and_position(selected_shader->get_program());

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_3D, volume_texture_id);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, edge_table_texture_id);
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, triangle_table_texture_id);

    while (!glfwWindowShouldClose(window)) {
        float currentFrame = glfwGetTime();
        // calculate the time it took to compute the new frame to move the camera in a smoother way depending on the framerate
        delta_time = currentFrame - last_frame_time;
        last_frame_time = currentFrame;
        glfwGetFramebufferSize(window, &width, &height);


        uploadMatrices(selected_shader->get_program());
        upload_iso_value_and_voxel_size(selected_shader->get_program());
        upload_lights_and_position(selected_shader->get_program());

        // specify the background color
        glClearColor(0.2f, 0.2f, 0.2f, 1.0f);
        // clear color, depth and stencil buffer
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        glBindBuffer(GL_ARRAY_BUFFER, VBO);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, GLsizei (3 * sizeof(float)), (GLvoid *) 0);
        glDrawArrays(GL_POINTS, 0, points.size());

        if(show_voxels) {
            uploadMatrices(cube_shader->get_program());
            upload_iso_value_and_voxel_size(cube_shader->get_program());
            upload_lights_and_position(cube_shader->get_program());
            glDrawArrays(GL_POINTS, 0, points.size());
        }

        draw_imgui_windows();

        glfwPollEvents();
        glfwSwapBuffers(window);
    }

    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();

    // unbinding shader program
    glUseProgram(NULL);
    // window is no longer required
    glfwDestroyWindow(window);
    // finish glfw
    glfwTerminate();
    return 0;
}

void upload_iso_value_and_voxel_size(GLuint shader){
    glUseProgram(shader);
    int dimensions_location = glGetUniformLocation(shader, "volume_dimensions");
    int iso_value_location = glGetUniformLocation(shader, "iso_value");
    int voxel_size_location = glGetUniformLocation(shader, "voxel_size");
    int mode_location = glGetUniformLocation(shader, "mode");
    glUniform1i(mode_location, current_mode);
    glUniform1f(iso_value_location, current_iso_value);
    glUniform1f(voxel_size_location, current_voxel_size);
    glUniform3f(dimensions_location, x_dim, y_dim, z_dim);
}

void generate_table_textures(){
    // generate texture for the edge table since it is to large to be stored in the geometry shader itself
    glGenTextures(1, &edge_table_texture_id);
    //glActiveTexture(GL_TEXTURE1);
    glEnable(GL_TEXTURE_2D);

    glBindTexture(GL_TEXTURE_2D, edge_table_texture_id);
    glUniform1i(glGetUniformLocation(marching_cubes_shader->get_program(), "edgeTable"), 1);
    glUniform1i(glGetUniformLocation(marching_tetracubes_shader->get_program(), "edgeTable"), 1);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

    glTexImage2D( GL_TEXTURE_2D, 0, GL_R32I , 256, 1, 0, GL_RED_INTEGER, GL_INT, &edgeTable);

    // generate texture for the triangle table since it is to large to be stored in the geometry shader itself
    glGenTextures(1, &triangle_table_texture_id);

    //glActiveTexture(GL_TEXTURE2);
    glEnable(GL_TEXTURE_2D);

    glBindTexture(GL_TEXTURE_2D, triangle_table_texture_id);
    glUniform1i(glGetUniformLocation(marching_cubes_shader->get_program(), "triTable"), 2);
    glUniform1i(glGetUniformLocation(marching_tetracubes_shader->get_program(), "triTable"), 2);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glTexImage2D( GL_TEXTURE_2D, 0, GL_R32I, 16, 256, 0, GL_RED_INTEGER, GL_INT, &triTable);


    //==========================================TRANSVOXEL_SHIT=========================================================
    glGenTextures(1, &cell_class_id);
    //glActiveTexture(GL_TEXTURE3);
    glEnable(GL_TEXTURE_2D);

    glBindTexture(GL_TEXTURE_2D, cell_class_id);
    glUniform1i(glGetUniformLocation(marching_cubes_transvoxel_shader->get_program(), "cellClass"), 1);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

    glTexImage2D( GL_TEXTURE_2D, 0, GL_R32I , 256, 1, 0, GL_RED_INTEGER, GL_INT, &regularCellClass);
    //__________________________________________________________________________________________________________________
    glGenTextures(1, &cell_data_id);
    //glActiveTexture(GL_TEXTURE4);
    glEnable(GL_TEXTURE_2D);

    glBindTexture(GL_TEXTURE_2D, cell_data_id);
    glUniform1i(glGetUniformLocation(marching_cubes_transvoxel_shader->get_program(), "cellData"), 2);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glTexImage2D( GL_TEXTURE_2D, 0, GL_R32I, 16, 16, 0, GL_RED_INTEGER, GL_INT, &regularCellData);
    //__________________________________________________________________________________________________________________
    glGenTextures(1, &regular_vertex_data_id);
    //glActiveTexture(GL_TEXTURE5);
    glEnable(GL_TEXTURE_2D);

    glBindTexture(GL_TEXTURE_2D, regular_vertex_data_id);
    glUniform1i(glGetUniformLocation(marching_cubes_transvoxel_shader->get_program(), "vertexData"), 3);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glTexImage2D( GL_TEXTURE_2D, 0, GL_R32I, 12, 256, 0, GL_RED_INTEGER, GL_INT, &regularVertexData);
    //__________________________________________________________________________________________________________________
    glGenTextures(1, &transition_cell_class_id);
    //glActiveTexture(GL_TEXTURE3);
    glEnable(GL_TEXTURE_2D);

    glBindTexture(GL_TEXTURE_2D, transition_cell_class_id);
    glUniform1i(glGetUniformLocation(marching_cubes_transvoxel_shader->get_program(), "transitionCellClass"), 4);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

    glTexImage2D( GL_TEXTURE_2D, 0, GL_R32I , 512, 1, 0, GL_RED_INTEGER, GL_INT, &transitionCellClass);
    //__________________________________________________________________________________________________________________
    glGenTextures(1, &transition_cell_data_id);
    //glActiveTexture(GL_TEXTURE5);
    glEnable(GL_TEXTURE_2D);

    glBindTexture(GL_TEXTURE_2D, transition_cell_data_id);
    glUniform1i(glGetUniformLocation(marching_cubes_transvoxel_shader->get_program(), "transitionCellData"), 5);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glTexImage2D( GL_TEXTURE_2D, 0, GL_R32I, 37, 56, 0, GL_RED_INTEGER, GL_INT, &transitionCellData);
    //__________________________________________________________________________________________________________________
    glGenTextures(1, &transition_vertex_data_id);
    //glActiveTexture(GL_TEXTURE5);
    glEnable(GL_TEXTURE_2D);

    glBindTexture(GL_TEXTURE_2D, transition_vertex_data_id);
    glUniform1i(glGetUniformLocation(marching_cubes_transvoxel_shader->get_program(), "transitionCellVertexData"), 6);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glTexImage2D( GL_TEXTURE_2D, 0, GL_R32I, 12, 512, 0, GL_RED_INTEGER, GL_INT, &transitionVertexData);

}

void compute_voxel_points(unsigned short x_dim, unsigned short y_dim, unsigned short z_dim, float voxel_size){
    points.clear();
    for(int i = 0; i < ((int)1.0f/voxel_size) * x_dim; ++i){
        for(int j = 0; j < ((int)1.0f/voxel_size) * y_dim; ++j){
            for(int k = 0; k < ((int)1.0f/voxel_size) * z_dim; ++k){
                points.emplace_back(i*voxel_size,j*voxel_size,k*voxel_size);
            }
        }
    }

    glGenVertexArrays(1, &VAO);
    glBindVertexArray(VAO);
    glGenBuffers(1,&VBO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(float) * 3 * points.size(), points.data(), GL_STATIC_DRAW);
}

void load_raw_volume(const char* raw_volume_path, unsigned short x_dim, unsigned short y_dim, unsigned short z_dim){
    FILE *file = fopen(raw_volume_path, "rb");
    if(file == NULL){
        std::cout << "could not load the volume\n";
        return;
    }

    if(sample){
        x_dim = 4;
        y_dim = 4;
        z_dim = 4;
    }

    GLubyte *volume = new GLubyte[x_dim * y_dim * z_dim];

    if(sample){
        for(int i = 0; i < x_dim * y_dim * z_dim; ++i) {
            *(volume + i) = i;
        }
    } else {
        fread(volume, sizeof(GLubyte), x_dim * y_dim * z_dim, file);
        fclose(file);
    }

    glGenTextures(1, &volume_texture_id);
    glBindTexture(GL_TEXTURE_3D, volume_texture_id);

    glUniform1i(glGetUniformLocation(marching_cubes_shader->get_program(), "volume"), 0);
    glUniform1i(glGetUniformLocation(marching_tetracubes_shader->get_program(), "volume"), 0);
    glUniform1i(glGetUniformLocation(marching_cubes_transvoxel_shader->get_program(), "volume"), 0);

    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP);

    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

    glTexImage3D(GL_TEXTURE_3D, 0, GL_INTENSITY, x_dim, y_dim, z_dim, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, volume);
    delete[] volume;

};

void upload_lights_and_position(GLuint shader){
    glUseProgram(shader);
    int light_position_location = glGetUniformLocation(shader, "light_position");
    int light_specular_color_location = glGetUniformLocation(shader, "light_specular_color");
    int light_diffuse_color_location = glGetUniformLocation(shader, "light_diffuse_color");
    int ambient_light_color_location = glGetUniformLocation(shader, "ambient_light_color");
    int camera_position_location = glGetUniformLocation(shader, "camera_position");
    int shininess_location = glGetUniformLocation(shader, "shininess");
    int lod_location = glGetUniformLocation(shader, "lod");
    int ss_location = glGetUniformLocation(shader, "surface_shift");
    int pr_location = glGetUniformLocation(shader, "project_transvoxel");

    glUniform3f(light_position_location, 0.0, 0.0, 10.0f);
    glUniform3f(light_specular_color_location, 255.0f / 255.0f, 255.0f / 255.0f, 160.0f / 255.0f);
    glUniform3f(light_diffuse_color_location, 255.0f / 255.0f, 255.0f / 255.0f, 160.0f / 255.0f);
    glUniform3f(ambient_light_color_location, 0.1, 0.1, 0.1);
    glUniform3f(camera_position_location, camera->Position.x, camera->Position.y, camera->Position.z);
    glUniform1f(shininess_location, 30.0f);
    glUniform1i(lod_location, lod);
    glUniform1i(ss_location, surface_shift);
    glUniform1i(pr_location, project_transvoxel);
}

void draw_imgui_windows(){
        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplGlfw_NewFrame();
        ImGui::NewFrame();
        ImGui::SetNextWindowSize({350, 300});
        ImGui::Begin("Statistics");
        ImGui::Text("Position: %f, %f, %f", camera->Position.x, camera->Position.y, camera->Position.z);
        ImGui::Text("Current Iso-value[P,L]: %f", current_iso_value);
        ImGui::Text("Current Voxel-size[O,K]: %f", current_voxel_size);
        if(current_mode == 1)
            ImGui::Text("Current mode[M]: Marching Cubes");
        else if(current_mode == 2)
            ImGui::Text("Current mode[M]: Marching Tetracubes");
        else if(current_mode == 3)
            ImGui::Text("Current mode[M]: Marching Cubes - Transvoxel");
        if(show_voxels){
            ImGui::Text("Display Voxel/Tetrahedra[E]: On");
        } else {
            ImGui::Text("Display Voxel/Tetrahedra[E]: Off");
        }
        if(lod == 1){
            ImGui::Text("LOD[R]: On");
        } else {
            ImGui::Text("LOD[R]: Off");
        }

        if(surface_shift == 1){
            ImGui::Text("Surface Shift[T]: On");
        } else {
            ImGui::Text("Surface Shift[T]: Off");
        }

        if(project_transvoxel == 1){
            ImGui::Text("Project Transvoxel Vertices[F]: On");
        } else {
            ImGui::Text("Project Transvoxel Vertices[F]: Off");
        }

        ImGui::End();
        ImGui::Render();
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
};

// this function is called when a key is pressed
void key_callback(GLFWwindow *window, int key, int scancode, int action, int mods) {
    // if the escape key is pressed the window will close
    if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS) {
        glfwSetWindowShouldClose(window, GL_TRUE);
    }

    if (key == GLFW_KEY_1 && action == GLFW_PRESS) {
        if (wireframe) {
            wireframe = false;
            glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
        } else {
            wireframe = true;
            glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
        }
    }

    if (key == GLFW_KEY_F && action == GLFW_PRESS) {
        project_transvoxel = !project_transvoxel;
    }

    if (key == GLFW_KEY_M && action == GLFW_PRESS) {
        current_mode = (current_mode % 3) + 1;

        switch (current_mode) {
            case 1:
            {
                selected_shader = marching_cubes_shader;
                glUseProgram(selected_shader->get_program());
                glActiveTexture(GL_TEXTURE0);
                glBindTexture(GL_TEXTURE_3D, volume_texture_id);
                glActiveTexture(GL_TEXTURE1);
                glBindTexture(GL_TEXTURE_2D, edge_table_texture_id);
                glActiveTexture(GL_TEXTURE2);
                glBindTexture(GL_TEXTURE_2D, triangle_table_texture_id);
                break;
            }

            case 2:
            {
                selected_shader = marching_tetracubes_shader;
                glUseProgram(selected_shader->get_program());
                glActiveTexture(GL_TEXTURE0);
                glBindTexture(GL_TEXTURE_3D, volume_texture_id);
                glActiveTexture(GL_TEXTURE1);
                glBindTexture(GL_TEXTURE_2D, edge_table_texture_id);
                glActiveTexture(GL_TEXTURE2);
                glBindTexture(GL_TEXTURE_2D, triangle_table_texture_id);
                break;
            }

            case 3:
            {
                selected_shader = marching_cubes_transvoxel_shader;
                glUseProgram(selected_shader->get_program());
                glActiveTexture(GL_TEXTURE0);
                glBindTexture(GL_TEXTURE_3D, volume_texture_id);
                glActiveTexture(GL_TEXTURE1);
                glBindTexture(GL_TEXTURE_2D, cell_class_id);
                glActiveTexture(GL_TEXTURE2);
                glBindTexture(GL_TEXTURE_2D, cell_data_id);
                glActiveTexture(GL_TEXTURE3);
                glBindTexture(GL_TEXTURE_2D, regular_vertex_data_id);
                glActiveTexture(GL_TEXTURE4);
                glBindTexture(GL_TEXTURE_2D, transition_cell_class_id);
                glActiveTexture(GL_TEXTURE5);
                glBindTexture(GL_TEXTURE_2D, transition_cell_data_id);
                glActiveTexture(GL_TEXTURE6);
                glBindTexture(GL_TEXTURE_2D, transition_vertex_data_id);
            }
        }
    }

    if (key == GLFW_KEY_T && action == GLFW_PRESS) {
        surface_shift = !surface_shift;
    }

    if (key == GLFW_KEY_R && action == GLFW_PRESS) {
        lod = (lod + 1) % 2;
    }

    if (key == GLFW_KEY_E && action == GLFW_PRESS) {
        show_voxels = !show_voxels;
    }

    if (key == GLFW_KEY_P && (action == GLFW_PRESS || action == GLFW_REPEAT)) {
        current_iso_value += 0.01f;
    }

    if (key == GLFW_KEY_O && action == GLFW_PRESS) {
        current_voxel_size += 0.5;
        compute_voxel_points(x_dim, y_dim, z_dim, current_voxel_size);
    }

    if (key == GLFW_KEY_K && action == GLFW_PRESS) {
        current_voxel_size -= 0.5;
        if(current_voxel_size <= 0.001f)
            current_voxel_size = 1.0f;
        compute_voxel_points(x_dim, y_dim, z_dim, current_voxel_size);
    }

    if (key == GLFW_KEY_L && (action == GLFW_PRESS || action == GLFW_REPEAT)) {
        current_iso_value -= 0.01f;
        if(current_iso_value < 0.0f)
            current_iso_value = 0.0f;
    }

    if (key == GLFW_KEY_W) {
        if (action == GLFW_PRESS || action == GLFW_REPEAT) {
            camera->ProcessKeyboard(FORWARD, delta_time * 50);
        }

    }

    if (key == GLFW_KEY_S) {
        if (action == GLFW_PRESS || action == GLFW_REPEAT) {
            camera->ProcessKeyboard(BACKWARD, delta_time * 50);
        }
    }
    //left and right
    if (key == GLFW_KEY_D) {
        if (action == GLFW_PRESS || action == GLFW_REPEAT) {
            camera->ProcessKeyboard(RIGHT, delta_time * 50);
        }
    }

    if (key == GLFW_KEY_A) {
        if (action == GLFW_PRESS || action == GLFW_REPEAT) {
            camera->ProcessKeyboard(LEFT, delta_time * 50);
        }
    }
}

void mouse_callback(GLFWwindow *window, double x, double y) {
    if (first_mouse) {
        last_x = x;
        last_y = y;
        first_mouse = false;
    }

    float xoffset = x - last_x;
    float yoffset = last_y - y; // reversed since y-coordinates go from bottom to top

    glfwSetCursorPos(window, last_x, last_y);
    camera->ProcessMouseMovement(xoffset, yoffset);
}

// this function is called when the window is resized
void framebuffer_size_callback(GLFWwindow *window, int width, int height) {
    glViewport(0, 0, width, height);
}

// this function uploads the model, view and projection matrix to the shader if they are defined in the shader
void uploadMatrices(GLuint shader) {
    glUseProgram(shader);
    glm::mat4 model = glm::mat4(1.0f);
    model = glm::scale(model, glm::vec3{1.0f/((float)x_dim)});
    glm::mat4 view = camera->GetViewMatrix();
    glm::mat4 projection = glm::perspective(glm::radians(60.0f), width / (float) height, 0.1f, 10000.0f);

    glUniformMatrix4fv(glGetUniformLocation(shader, "model"), 1, GL_FALSE, &model[0][0]);
    glUniformMatrix4fv(glGetUniformLocation(shader, "projection"), 1, GL_FALSE, &projection[0][0]);
    glUniformMatrix4fv(glGetUniformLocation(shader, "view"), 1, GL_FALSE, &view[0][0]);
}

void initialize() {
    // initialize the GLFW library to be able create a window
    if (!glfwInit()) {
        throw std::runtime_error("Couldn't init GLFW");
    }

    // set the opengl version
    /*
    int major = 3;
    int minor = 3;
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, major);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, minor);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    */
    // create the window
    window = glfwCreateWindow(width, height, "OpenGL Marching Cubes/Tetrahedra", NULL, NULL);

    if (!window) {
        glfwTerminate();
        throw std::runtime_error("Couldn't create a window");
    }

    // set the window to the current context so that it is used
    glfwMakeContextCurrent(window);
    // set the frameBufferSizeCallback so that the window adjusts if it is scaled
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    // set the keyCallback function so that keyboard input can be used
    glfwSetKeyCallback(window, key_callback);
    // set the mouse callback so that mouse input can be used
    glfwSetCursorPosCallback(window, mouse_callback);

    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);


    // try to initialise glew to be able to use opengl commands
    glewExperimental = GL_TRUE;
    GLenum err = glewInit();

    if (err != GLEW_OK) {
        glfwTerminate();
        throw std::runtime_error(
                std::string("Could initialize GLEW, error = ") + (const char *) glewGetErrorString(err));
    }

    const GLubyte *renderer = glGetString(GL_RENDERER);
    const GLubyte *version = glGetString(GL_VERSION);
    std::cout << "Renderer: " << renderer << std::endl;
    std::cout << "OpenGL version supported " << version << std::endl;


    // opengl configuration
    glEnable(GL_DEPTH_TEST);        // enable depth-testing
    glDepthFunc(GL_LESS);           // depth-testing interprets a smaller value as "closer"
    glfwSwapInterval(false); // disables VSYNC

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO &io = ImGui::GetIO();
    (void) io;
    // Setup Dear ImGui style
    ImGui::StyleColorsDark();
    //ImGui::StyleColorsClassic();
    const char *glsl_version = "#version 130";
    // Setup Platform/Renderer bindings
    ImGui_ImplGlfw_InitForOpenGL(window, true);
    ImGui_ImplOpenGL3_Init(glsl_version);
}