#version 430
layout (points) in;
layout (points, max_vertices = 16) out;

uniform sampler3D volume;

uniform vec3 volume_dimensions;

uniform mat4 view;
uniform mat4 projection;
uniform mat4 model;

// has to be done since the texture coordinates are between 0,0,0 and 1,1,1
vec3 texture_position(vec4 position){
    return position.xyz/volume_dimensions;
}

float sample_volume(vec4 position){
    return texture(volume, texture_position(position)).a;
}

void main() {
    mat4 mvp = projection * view * model;
    if(sample_volume(gl_in[0].gl_Position) > 0.2){
        gl_Position = mvp * gl_in[0].gl_Position;
        EmitVertex();
    }

    EndPrimitive();
}