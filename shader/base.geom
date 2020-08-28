#version 430
layout (points) in;
layout (points, max_vertices = 16) out;

uniform sampler3D volume;

uniform vec3 volume_dimensions;

uniform mat4 view;
uniform mat4 projection;
uniform mat4 model;

vec4 corner_1 = vec4(0,0,0,0);
vec4 corner_2 = vec4(0,0,1,0);
vec4 corner_3 = vec4(0,1,0,0);
vec4 corner_4 = vec4(0,1,1,0);
vec4 corner_5 = vec4(1,0,0,0);
vec4 corner_6 = vec4(1,0,1,0);
vec4 corner_7 = vec4(1,1,0,0);
vec4 corner_8 = vec4(1,1,1,0);

// has to be done since the texture coordinates are between 0,0,0 and 1,1,1
vec3 texture_position(vec4 position){
    return position.xyz/volume_dimensions;
}

float sample_volume(vec4 position){
    return texture(volume, texture_position(position)).a;
}

void main() {
    mat4 mvp = projection * view * model;
    if(sample_volume(gl_in[0].gl_Position + corner_1) > 0.2){
        gl_Position = mvp * gl_in[0].gl_Position;
        EmitVertex();
    }
    if(sample_volume(gl_in[0].gl_Position + corner_2) > 0.2){
        gl_Position = mvp * gl_in[0].gl_Position;
        EmitVertex();
    }
    if(sample_volume(gl_in[0].gl_Position + corner_3) > 0.2){
        gl_Position = mvp * gl_in[0].gl_Position;
        EmitVertex();
    }
    if(sample_volume(gl_in[0].gl_Position + corner_4) > 0.2){
        gl_Position = mvp * gl_in[0].gl_Position;
        EmitVertex();
    }
    if(sample_volume(gl_in[0].gl_Position + corner_5) > 0.2){
        gl_Position = mvp * gl_in[0].gl_Position;
        EmitVertex();
    }
    if(sample_volume(gl_in[0].gl_Position + corner_6) > 0.2){
        gl_Position = mvp * gl_in[0].gl_Position;
        EmitVertex();
    }
    if(sample_volume(gl_in[0].gl_Position + corner_7) > 0.2){
        gl_Position = mvp * gl_in[0].gl_Position;
        EmitVertex();
    }
    if(sample_volume(gl_in[0].gl_Position + corner_8) > 0.2){
        gl_Position = mvp * gl_in[0].gl_Position;
        EmitVertex();
    }

    EndPrimitive();
}