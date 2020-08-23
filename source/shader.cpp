#include "../include/shader.h"


Shader::Shader(std::string const &vert_shader_path, std::string const &frag_shader_path) {
    load_shaders(vert_shader_path, frag_shader_path);
}

std::string Shader::read_shader(std::string const &name) {
    std::ifstream ifile(name);

    if (ifile) {
        std::string filetext;

        while (ifile.good()) {
            std::string line;
            std::getline(ifile, line);
            filetext.append(line + "\n");
        }

        return filetext;
    } else {
        throw std::invalid_argument(name);
    }
}

void Shader::load_shaders(std::string const& vertexShaderPath, std::string const& fragmentShaderPath) {
    // creating program, vertex and fragment shaders
    GLuint shaderProgram = glCreateProgram();
    GLuint vertShader = glCreateShader(GL_VERTEX_SHADER);
    GLuint fragShader = glCreateShader(GL_FRAGMENT_SHADER);

    std::string verShader_source{read_shader(vertexShaderPath)};
    const char *vertShader_chars = verShader_source.c_str();
    std::string fragShader_source{read_shader(fragmentShaderPath)};
    const char *fragShader_chars = fragShader_source.c_str();

    // associate the shader source code with a shader object
    glShaderSource(vertShader, 1, &vertShader_chars, NULL);
    glShaderSource(fragShader, 1, &fragShader_chars, NULL);

    // compiling vertex shader
    glCompileShader(vertShader);
    checkShaderError(vertShader, GL_COMPILE_STATUS);

    // compiling fragment shader
    glCompileShader(fragShader);
    checkShaderError(fragShader, GL_COMPILE_STATUS);


    // attaching vertex and fragment shaders in one program
    glAttachShader(shaderProgram, vertShader);
    glAttachShader(shaderProgram, fragShader);

    // linking
    glLinkProgram(shaderProgram);
    checkShaderError(shaderProgram, GL_COMPILE_STATUS);

    // detach the vertex and fragment shader
    glDetachShader(shaderProgram, vertShader);
    glDetachShader(shaderProgram, fragShader);

    // delete vertex and fragment shader because
    // they are linked into a program
    glDeleteShader(vertShader);
    glDeleteShader(fragShader);
    shader_program = shaderProgram;
}

GLuint Shader::get_program() {
    return shader_program;
}

bool Shader::checkShaderError(GLuint shaderID, GLuint status) {
    int succes;
    char log[1024];
    // Get compilation status
    glGetShaderiv(shaderID, status, &succes);
    // Compilation error
    if (!succes) {
        // Gets the error message
        glGetShaderInfoLog(shaderID, 1024, NULL, log);
        std::cout << "Shader ERROR: " << log << std::endl;
        return false;
    }
    return true;
}


