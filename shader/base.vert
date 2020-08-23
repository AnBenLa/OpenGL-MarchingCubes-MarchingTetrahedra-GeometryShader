#version 330 core

layout (location = 0) in vec3 in_position;

uniform mat4 view;
uniform mat4 projection;
uniform mat4 model;

out vec3 position;

void main(){
    gl_Position = projection * view * model *  vec4(in_position, 1.0);

    position = (model *  vec4(in_position, 1.0)).xyz;
}