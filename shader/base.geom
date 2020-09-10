#version 430
layout (points) in;
layout (triangle_strip, max_vertices = 16) out;

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

int tetrahedrons[6][4] = {
{ 3, 0, 7, 6 },
{ 7, 0, 4, 6 },
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

int tetrahedra_triangle_map[16][6] = {
{ -1, -1, -1, -1, -1, -1 },
{ 0, 2, 1, -1, -1, -1 },
{ 1, 4, 3, -1, -1, -1 },
{ 4, 0, 2, 4, 2, 3 },
{ 2, 3, 5, -1, -1, -1 },
{ 0, 1, 5, 1, 5, 3 },
{ 1, 2, 5, 1, 5, 4 },
{ 4, 5, 0, -1, -1, -1 },
{ 4, 5, 0, -1, -1, -1 },
{ 1, 2, 5, 1, 5, 4 },
{ 0, 1, 5, 1, 5, 3 },
{ 2, 3, 5, -1, -1, -1 },
{ 4, 0, 2, 4, 2, 3 },
{ 1, 4, 3, -1, -1, -1 },
{ 0, 2, 1, -1, -1, -1 },
{ -1, -1, -1, -1, -1, -1 }
};

// defines which corners make the edge determined by the first index
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

void marching_cubes(){
    float[8] corner_sample;
    mat4 mvp = projection * view * model;
    int cube_index = 0;

    int k = 1;

    // sample the volume at each corner and store the result in the corner sample array
    // compute the index of the cube that will define which triangles will be generated
    // this works already
    for (int i = 0; i < 8; i++){
        corner_sample[i] = sample_volume(gl_in[0].gl_Position + corner[i]);
        if (corner_sample[i] < iso_value) cube_index |= k;
        // do a bit shift in order to multiply with 2 faster
        k = k << 1;
    }

    // working!
    int cut_edges = texelFetch(edgeTable, ivec2(cube_index, 0), 0).r;

    vec4[12] vertices;
    k = 1;

    //in case the whole cube is outside the volume
    if (cut_edges == 0)
    return;

    // for all possible vertices that could be generated calculate the new interpolated vertex position if the vertex will be used
    for (int i = 0; i < 12; ++i){
        if ((cut_edges & k) == k){
            int a_index = edge_vertex_mapping[i][0];
            int b_index = edge_vertex_mapping[i][1];
            vec4 a = gl_in[0].gl_Position + corner[a_index];
            vec4 b = gl_in[0].gl_Position + corner[b_index];
            float value_a = corner_sample[a_index];
            float value_b = corner_sample[b_index];
            vertices[i] = interpolate_vertex(iso_value, a, b, value_a, value_b);
        }
        k = k << 1;
    }

    // chech which vertices will form a triangle by looking up in the triangle table
    // generate the triangles
    for (int i = 0; texelFetch(triTable, ivec2(i, cube_index), 0).r != -1; i += 3){
        vec4 vert_a = vertices[texelFetch(triTable, ivec2(i, cube_index), 0).r];
        vec4 vert_b = vertices[texelFetch(triTable, ivec2(i+1, cube_index), 0).r];
        vec4 vert_c = vertices[texelFetch(triTable, ivec2(i+2, cube_index), 0).r];

        vec3 a = vert_a.xyz - vert_b.xyz;
        vec3 b = vert_c.xyz - vert_b.xyz;
        frag.normal = normalize(cross(a, b));

        gl_Position = mvp * vert_a;
        frag.position = gl_Position.xyz;
        frag.color = vec4(1.0, 0, 0, 1.0);
        EmitVertex();

        gl_Position = mvp * vert_b;
        frag.position = gl_Position.xyz;
        frag.color = vec4(1.0, 0.0, 0, 1.0);
        EmitVertex();

        gl_Position = mvp * vert_c;
        frag.position = gl_Position.xyz;
        frag.color = vec4(1, 0, 0.0, 1.0);
        EmitVertex();
        EndPrimitive();
    }
}

void marching_tetracubes(){
    float[8] corner_sample;
    mat4 mvp = projection * view * model;
    int cube_index = 0;

    // store the corner values to avoid recomputation
    for (int i = 0; i < 8; i++){
        corner_sample[i] = sample_volume(gl_in[0].gl_Position + corner[i]);
    }

    // for each tetrahedron
    for (int i = 0; i < 6; ++i){
        int k = 1;
        // check all 4 corners of the current tetrahedron
        for (int j = 0; j < 4; ++j){
            if (corner_sample[tetrahedrons[i][j]] > iso_value) cube_index |= k;
            k = k << 1;
        }

        for (int k = 0; tetrahedra_triangle_map[cube_index][k] != -1; k += 3){

            int edge_0 = tetrahedra_triangle_map[cube_index][k];
            int edge_1 = tetrahedra_triangle_map[cube_index][k + 1];
            int edge_2 = tetrahedra_triangle_map[cube_index][k + 2];

            vec4 vertex_edge_0_a = gl_in[0].gl_Position + corner[tetrahedrons[i][tetrahedra_edge_vertex_mapping[edge_0][0]]];
            vec4 vertex_edge_0_b = gl_in[0].gl_Position + corner[tetrahedrons[i][tetrahedra_edge_vertex_mapping[edge_0][1]]];

            float vertex_edge_0_a_value = corner_sample[tetrahedrons[i][tetrahedra_edge_vertex_mapping[edge_0][0]]];
            float vertex_edge_0_b_value = corner_sample[tetrahedrons[i][tetrahedra_edge_vertex_mapping[edge_0][1]]];

            vec4 vert_a = interpolate_vertex(iso_value, vertex_edge_0_a, vertex_edge_0_b, vertex_edge_0_a_value, vertex_edge_0_b_value);
            vert_a = (vertex_edge_0_a + vertex_edge_0_b) / 2.0f;

            vec4 vertex_edge_1_a = gl_in[0].gl_Position + corner[tetrahedrons[i][tetrahedra_edge_vertex_mapping[edge_1][0]]];
            vec4 vertex_edge_1_b = gl_in[0].gl_Position + corner[tetrahedrons[i][tetrahedra_edge_vertex_mapping[edge_1][1]]];

            float vertex_edge_1_a_value = corner_sample[tetrahedrons[i][tetrahedra_edge_vertex_mapping[edge_1][0]]];
            float vertex_edge_1_b_value = corner_sample[tetrahedrons[i][tetrahedra_edge_vertex_mapping[edge_1][1]]];

            vec4 vert_b = interpolate_vertex(iso_value, vertex_edge_1_a, vertex_edge_1_b, vertex_edge_1_a_value, vertex_edge_1_b_value);
            vert_b = (vertex_edge_1_a + vertex_edge_1_b) / 2.0f;

            vec4 vertex_edge_2_a = gl_in[0].gl_Position + corner[tetrahedrons[i][tetrahedra_edge_vertex_mapping[edge_2][0]]];
            vec4 vertex_edge_2_b = gl_in[0].gl_Position + corner[tetrahedrons[i][tetrahedra_edge_vertex_mapping[edge_2][1]]];

            float vertex_edge_2_a_value = corner_sample[tetrahedrons[i][tetrahedra_edge_vertex_mapping[edge_2][0]]];
            float vertex_edge_2_b_value = corner_sample[tetrahedrons[i][tetrahedra_edge_vertex_mapping[edge_2][1]]];

            vec4 vert_c = interpolate_vertex(iso_value, vertex_edge_2_a, vertex_edge_2_b, vertex_edge_2_a_value, vertex_edge_2_b_value);
            vert_c = (vertex_edge_2_a + vertex_edge_2_b) / 2.0f;

            vec3 a = vert_a.xyz - vert_b.xyz;
            vec3 b = vert_c.xyz - vert_b.xyz;
            frag.normal = normalize(cross(a, b));

            gl_Position = mvp * vert_a;
            frag.position = gl_Position.xyz;
            frag.color = vec4(1.0, 0, 0, 1.0);
            EmitVertex();

            gl_Position = mvp * vert_b;
            frag.position = gl_Position.xyz;
            frag.color = vec4(1.0, 0.0, 0, 1.0);
            EmitVertex();

            gl_Position = mvp * vert_c;
            frag.position = gl_Position.xyz;
            frag.color = vec4(1, 0, 0.0, 1.0);
            EmitVertex();
            EndPrimitive();
        }


    }
}

void main() {
    // scale the voxels according to the voxel size
    for (int i = 0; i < 8; ++i)
    corner[i] = voxel_size * corner[i];

    if (mode == 1)
    marching_cubes();
    else if (mode == 2)
    marching_tetracubes();
}