#version 430
layout (points) in;
layout (line_strip, max_vertices = 72) out;

out fData
{
    vec3 position;
    vec3 normal;
    vec4 color;
}frag;

layout(binding=0) uniform sampler3D volume;
layout(binding=1) uniform isampler2D edgeTable;
layout(binding=2) uniform isampler2D triTable;

uniform vec3 volume_dimensions;
uniform float iso_value;
uniform float voxel_size;
// 1 if marching cubes, 2 if marching tetrahedra
uniform int mode;

uniform mat4 view;
uniform mat4 projection;
uniform mat4 model;

vec4[8] corner = {
vec4(0, 0, 1, 0),
vec4(1, 0, 1, 0),
vec4(1, 0, 0, 0),
vec4(0, 0, 0, 0),

vec4(0, 1, 1, 0),
vec4(1, 1, 1, 0),
vec4(1, 1, 0, 0),
vec4(0, 1, 0, 0) };

int edge_vertex_mapping[12][2] = {
{ 0, 1 },
{ 1, 2 },
{ 2, 3 },
{ 0, 3 },
{ 4, 5 },
{ 5, 6 },
{ 6, 7 },
{ 4, 7 },
{ 0, 4 },
{ 1, 5 },
{ 2, 6 },
{ 3, 7 }
};

int tetrahedrons[6][4] = {
{ 3, 0, 7, 6 },
{ 4, 0, 7, 6 },
{ 0, 4, 5, 6 },
{ 5, 6, 1, 0 },
{ 0, 1, 2, 6 },
{ 0, 3, 2, 6 }
};

int tetrahedra_edge_vertex_mapping[6][2] = {
{ 0, 3 },
{ 0, 1 },
{ 0, 2 },
{ 1, 2 },
{ 1, 3 },
{ 2, 3 }
};

// has to be done since the texture coordinates are between 0,0,0 and 1,1,1
vec3 texture_position(vec4 position){
    return position.xyz/volume_dimensions;
}

float sample_volume(vec4 position){
    return texture(volume, texture_position(position)).a;
}

vec4 interpolate_vertex(float iso_value, vec4 a, vec4 b, float value_a, float value_b){
    return vec4((a + (iso_value - value_a)*(b - a)/(value_b - value_a)).xyz, 1);
}



void main() {
    // scale the voxels according to the voxel size
    for (int i = 0; i < 8; ++i)
        corner[i] = voxel_size * corner[i];

    float[8] corner_sample;
    mat4 mvp = projection * view * model;
    int k = 1;
    int cube_index = 0;

    for (int i = 0; i < 8; i++){
        corner_sample[i] = sample_volume(gl_in[0].gl_Position + corner[i]);
        if (corner_sample[i] < iso_value) cube_index |= k;
        k = k << 1;
    }


    if(false || (cube_index != 0 && cube_index != 255)){
        if(mode == 1){
            for (int i = 0; i < 12; ++i){
                gl_Position = mvp * (gl_in[0].gl_Position + corner[edge_vertex_mapping[i][0]]);
                EmitVertex();
                gl_Position = mvp * (gl_in[0].gl_Position + corner[edge_vertex_mapping[i][1]]);
                EmitVertex();
                EndPrimitive();
            }
        } else if (mode == 2){
            for(int i = 0; i < 6; ++i){
                for(int j = 0; j < 6; ++j){
                    gl_Position = mvp * (gl_in[0].gl_Position + corner[tetrahedrons[i][tetrahedra_edge_vertex_mapping[j][0]]]);
                    EmitVertex();
                    gl_Position = mvp * (gl_in[0].gl_Position + corner[tetrahedrons[i][tetrahedra_edge_vertex_mapping[j][1]]]);
                    EmitVertex();
                    EndPrimitive();
                }
            }
        }
    }
}
