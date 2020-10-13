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
uniform int lod;

uniform mat4 view;
uniform mat4 projection;
uniform mat4 model;
uniform vec3 camera_position;

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

int lod_function(vec3 voxel_position){
    if (length(camera_position - (model*vec4(voxel_position, 1)).xyz) > 0.5)
        return 2;
    else
        return 1;
}

void main() {
    int voxel_size_lod = 1;

    if(lod == 1){
        // voxel position
        int x = int(gl_in[0].gl_Position.x / voxel_size);
        int y = int(gl_in[0].gl_Position.y / voxel_size);
        int z = int(gl_in[0].gl_Position.z / voxel_size);

        // base voxel position
        float x_base = (x - (x%2)) * voxel_size;
        float y_base = (y - (y%2)) * voxel_size;
        float z_base = (z - (z%2)) * voxel_size;

        // check for voxel size / lod
        voxel_size_lod = lod_function(vec3(x_base, y_base, z_base));

        // check if voxel is covered
        // if covered return;
        if (voxel_size_lod == 2 && (x % 2 == 1 || y % 2 == 1 || z % 2 == 1)){
            return;
        }
    }

    for (int i = 0; i < 8; ++i)
        corner[i] = voxel_size_lod * voxel_size * corner[i];

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
        frag.normal = vec3(0,0,0);
        if(voxel_size_lod == 2)
            frag.color = vec4(1,0,0,1);
        else
            frag.color = vec4(0,0,1,1);
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
                cube_index = 0;
                int k = 1;
                // check all 4 corners of the current tetrahedron
                for (int j = 0; j < 4; ++j){
                    if (corner_sample[tetrahedrons[i][j]] < iso_value) cube_index |= k;
                    k = k << 1;
                }
                if(cube_index != 0 && cube_index != 15){
                    for (int j = 0; j < 6; ++j){
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
}
