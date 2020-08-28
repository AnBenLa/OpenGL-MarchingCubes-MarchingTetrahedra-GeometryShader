#version 430
layout (points) in;
layout (points, max_vertices = 16) out;

uniform sampler3D volume;
uniform isampler2D edgeTable;
uniform isampler2D triTable;

uniform vec3 volume_dimensions;

uniform mat4 view;
uniform mat4 projection;
uniform mat4 model;

vec4[8] corner = {
vec4(0,0,1,0),
vec4(1,0,1,0),
vec4(1,0,0,0),
vec4(0,0,0,0),
vec4(0,1,1,0),
vec4(1,1,1,0),
vec4(1,1,0,0),
vec4(0,1,0,0)};

// defines which corners make the edge determined by the first index
int edge_vertex_mapping[12][2] = {
    {0,1},
    {1,2},
    {2,3},
    {0,3},
    {4,5},
    {5,6},
    {6,7},
    {4,7},
    {0,4},
    {1,5},
    {2,6},
    {3,7}
};

// has to be done since the texture coordinates are between 0,0,0 and 1,1,1
vec3 texture_position(vec4 position){
    return position.xyz/volume_dimensions;
}

float sample_volume(vec4 position){
    return texture(volume, texture_position(position)).a;
}

vec4 interpolate_vertex(float iso_value, vec4 a, vec4 b, float value_a, float value_b){
    return a + (iso_value - value_a)*(b - a)/(value_b - value_a);
}

void main() {
    mat4 mvp = projection * view * model;
    int cube_index = 0;
    float iso_value = 0.2f;

    int k = 1;
    float[8] corner_sample;

    // sample the volume at each corner and store the result in the corner sample array
    // compute the index of the cube that will define which triangles will be generated
    for(int i = 0; i < 8; i++){
        corner_sample[i] = sample_volume(gl_in[0].gl_Position + corner[i]);
        if(corner_sample[i] < iso_value) cube_index |= k;
        // do a bit shift in order to multiply with 2 faster
        k = k << 1;
    }

    // check which edges will be cut by looking up in the edge table texture
    // TODO texture access needs to be checked!
    int cut_edges = texture(edgeTable, vec2(cube_index,1)).a;

    if(cut_edges != 0 && cut_edges != 255){
        gl_Position = mvp * gl_in[0].gl_Position;
        EmitVertex();
    }

    vec4[12] vertices;
    k = 1;

    // for all possible vertices that could be generated calculate the new interpolated vertex position if the vertex will be used
    for(int i = 0; i < 12; ++i){
        if((cut_edges & k) == k){
            int a_index = edge_vertex_mapping[k][0];
            int b_index = edge_vertex_mapping[k][1];
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
    // TODO texture access needs to be checked!
    for(int i = 0; texture(triTable, vec2(cube_index, i)).a != -1; i += 3){
        gl_Position = mvp * vertices[texture(triTable, vec2(cube_index, i)).a];
        EmitVertex();
        gl_Position = mvp * vertices[texture(triTable, vec2(cube_index, i + 1)).a];
        EmitVertex();
        gl_Position = mvp * vertices[texture(triTable, vec2(cube_index, i + 2)).a];
        EmitVertex();
        EndPrimitive;
    }

    EndPrimitive();
}