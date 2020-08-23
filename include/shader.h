#ifndef LAB_4_SHADER_H
#define LAB_4_SHADER_H

#include <GL/glew.h>
#include <string>
#include <fstream>
#include <vector>
#include <iostream>

class Shader {
public:
    Shader(std::string const &vPath, std::string const &fPath);
    GLuint get_program();
private:
    GLuint shader_program;
    std::string read_shader(std::string const&  path);
    bool checkShaderError(GLuint shaderID, GLuint status);
    void load_shaders(std::string const &vPath, std::string const &fPath);

};
#endif //LAB_4_SHADER_H
