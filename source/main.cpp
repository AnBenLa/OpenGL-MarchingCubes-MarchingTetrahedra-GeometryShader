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

int width = 800, height = 600;
float last_x, last_y, delta_time = 0.0f, last_frame_time = 0.0f;;
bool wireframe = false, first_mouse = false, collapse_edge = false, show_model = true;
Camera *camera = new Camera{glm::vec3{0, 0, 1}, glm::vec3{0, 1, 0}};
GLuint volume_texture_id;
GLFWwindow *window;

void key_callback(GLFWwindow *window, int key, int scancode, int action, int mods);

void mouse_callback(GLFWwindow *window, double x, double y);

void framebuffer_size_callback(GLFWwindow *window, int width, int height);

void uploadMatrices(GLuint shader);

void initialize();

void draw_imgui_windows();

void load_raw_volume(const char* raw_volume_path, unsigned short x_dim, unsigned short y_dim, unsigned short z_dim);

std::vector<glm::vec3> compute_voxel_points(unsigned short x_dim, unsigned short y_dim, unsigned short z_dim);

int main(int argc, const char *argv[]) {

    initialize();

    Shader normal_shader = Shader{"../shader/base.vert", "../shader/base.frag", "../shader/base.geom"};
    //Shader normal_shader = Shader{"../shader/base.vert", "../shader/base.frag"};
    glUseProgram(normal_shader.get_program());

    unsigned short x_dim = 32, y_dim = 32, z_dim = 32;
    int dimensions_location = glGetUniformLocation(normal_shader.get_program(), "volume_dimensions");
    glUniform3f(dimensions_location, x_dim, y_dim, z_dim);


    load_raw_volume("../volume_files/bucky.raw", x_dim, y_dim,z_dim);

    std::vector<glm::vec3> points = compute_voxel_points(x_dim, y_dim, z_dim);

    GLuint VBO, VAO;
    glGenVertexArrays(1, &VAO);
    glBindVertexArray(VAO);
    glGenBuffers(1,&VBO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(float) * 3 * points.size(), points.data(), GL_STATIC_DRAW);


    while (!glfwWindowShouldClose(window)) {
        float currentFrame = glfwGetTime();
        // calculate the time it took to compute the new frame to move the camera in a smoother way depending on the framerate
        delta_time = currentFrame - last_frame_time;
        last_frame_time = currentFrame;
        glfwGetFramebufferSize(window, &width, &height);

        uploadMatrices(normal_shader.get_program());

        // specify the background color
        glClearColor(0.2f, 0.2f, 0.2f, 1.0f);
        // clear color, depth and stencil buffer
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        glBindBuffer(GL_ARRAY_BUFFER, VBO);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, GLsizei (3 * sizeof(float)), (GLvoid *) 0);
        glDrawArrays(GL_POINTS, 0, points.size());


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

std::vector<glm::vec3> compute_voxel_points(unsigned short x_dim, unsigned short y_dim, unsigned short z_dim){
    std::vector<glm::vec3> points;
    for(int i = 0; i < x_dim; ++i){
        for(int j = 0; j < y_dim; ++j){
            for(int k = 0; k < z_dim; ++k){
                points.emplace_back(i,j,k);
            }
        }
    }
    return points;
}

void load_raw_volume(const char* raw_volume_path, unsigned short x_dim, unsigned short y_dim, unsigned short z_dim){
    FILE *file = fopen(raw_volume_path, "rb");
    if(file == NULL){
        std::cout << "could not load the volume\n";
        return;
    }

    GLubyte* volume = new GLubyte[x_dim * y_dim * z_dim];
    fread(volume, sizeof(GLubyte), x_dim * y_dim * z_dim, file);
    fclose(file);

    glGenTextures(1, &volume_texture_id);

    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP);

    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

    glTexImage3D(GL_TEXTURE_3D, 0, GL_INTENSITY, x_dim, y_dim, z_dim, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, volume);
    delete[] volume;
};

void draw_imgui_windows(){
        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplGlfw_NewFrame();
        ImGui::NewFrame();
        ImGui::SetNextWindowSize({350, 100});
        ImGui::Begin("Statistics");
        ImGui::Text("Position: %f, %f, %f", camera->Position.x, camera->Position.y, camera->Position.z);
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
    glm::mat4 model = glm::mat4(1.0f);
    model = glm::scale(model, glm::vec3{1.0f/32.0f});
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