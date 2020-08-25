#include "../include/shader.h"


Shader::Shader(std::string const &vert_shader_path, std::string const &frag_shader_path, std::string const &geom_shader_path) {
    load_shaders(vert_shader_path, frag_shader_path, geom_shader_path);
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

void Shader::load_shaders(std::string const& vertexShaderPath, std::string const& fragmentShaderPath, std::string const& geometryShaderPath) {
    // creating program, vertex and fragment shaders
    GLuint shaderProgram = glCreateProgram();
    GLuint vertShader = glCreateShader(GL_VERTEX_SHADER);
    GLuint fragShader = glCreateShader(GL_FRAGMENT_SHADER);
    GLuint geomShader = glCreateShader(GL_GEOMETRY_SHADER);

    std::string verShader_source{read_shader(vertexShaderPath)};
    const char *vertShader_chars = verShader_source.c_str();
    std::string fragShader_source{read_shader(fragmentShaderPath)};
    const char *fragShader_chars = fragShader_source.c_str();
    std::string geomShader_source;

    if(geometryShaderPath != "")
            geomShader_source = read_shader(geometryShaderPath);
    const char *geomShader_chars = geomShader_source.c_str();

    // associate the shader source code with a shader object
    glShaderSource(vertShader, 1, &vertShader_chars, NULL);
    glShaderSource(fragShader, 1, &fragShader_chars, NULL);
    if(geometryShaderPath != "")
        glShaderSource(geomShader, 1, &geomShader_chars, NULL);

    // compiling vertex shader
    glCompileShader(vertShader);
    checkShaderError(vertShader, GL_COMPILE_STATUS);

    // compiling fragment shader
    glCompileShader(fragShader);
    checkShaderError(fragShader, GL_COMPILE_STATUS);

    if(geometryShaderPath != ""){
        glCompileShader(geomShader);
        checkShaderError(geomShader, GL_COMPILE_STATUS);
    }

    // attaching vertex and fragment shaders in one program
    glAttachShader(shaderProgram, vertShader);
    glAttachShader(shaderProgram, fragShader);
    if(geometryShaderPath != ""){
        glAttachShader(shaderProgram, geomShader);
    }

    // linking
    glLinkProgram(shaderProgram);
    checkProgramError(shaderProgram, GL_COMPILE_STATUS);

    // detach the vertex and fragment shader
    glDetachShader(shaderProgram, vertShader);
    glDetachShader(shaderProgram, fragShader);
    glDetachShader(shaderProgram, geomShader);

    // delete vertex and fragment shader because
    // they are linked into a program
    glDeleteShader(vertShader);
    glDeleteShader(fragShader);
    glDeleteShader(geomShader);

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
    if (succes != 1) {
        // Gets the error message
        glGetShaderInfoLog(shaderID, 1024, NULL, log);
        std::cout << "Shader ERROR: " << log << std::endl;
        return false;
    }
    return true;
}

bool Shader::checkProgramError(GLuint shaderID, GLuint status) {
    int succes;
    char log[1024];
    // Get compilation status
    glGetProgramiv(shaderID, GL_LINK_STATUS, &succes);
    // Compilation error
    if (succes != 1) {
        // Gets the error message
        glGetProgramInfoLog(shaderID, 1024, NULL, log);
        std::cout << "Prgoram linking ERROR: " << log << std::endl;
        return false;
    }
    return true;
}


