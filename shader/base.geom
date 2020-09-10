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
    return vec4((a + (iso_value - value_a)*(b - a)/(value_b - value_a)).xyz, 1);
}

void main() {
    mat4 mvp = projection * view * model;
    int cube_index = 0;

    int k = 1;
    float[8] corner_sample;

    for(int i = 0; i < 8; ++i)
        corner[i] = voxel_size * corner[i];

    // sample the volume at each corner and store the result in the corner sample array
    // compute the index of the cube that will define which triangles will be generated
    // this works already
    for(int i = 0; i < 8; i++){
        corner_sample[i] = sample_volume(gl_in[0].gl_Position + corner[i]);
        if(corner_sample[i] < iso_value) cube_index |= k;
        // do a bit shift in order to multiply with 2 faster
        k = k << 1;
    }

    // working!
    int cut_edges = texelFetch(edgeTable, ivec2(cube_index,0), 0).r;
    //int abc =  texelFetch(triTable, ivec2(0, cube_index), 0).r;

    /*if(cut_edges > 0){
        gl_Position = mvp * gl_in[0].gl_Position;
        EmitVertex();
        gl_Position = mvp * (gl_in[0].gl_Position + corner[0]);
        EmitVertex();
        gl_Position = mvp * (gl_in[0].gl_Position + corner[1]);
        EmitVertex();
        EndPrimitive();
    }*/

    vec4[12] vertices;
    k = 1;

    //in case the whole cube is outside the volume
    if (cut_edges == 0)
        return;

    // for all possible vertices that could be generated calculate the new interpolated vertex position if the vertex will be used
    for(int i = 0; i < 12; ++i){
        if((cut_edges & k) == k){
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
    // TODO texture access needs to be checked!

    for(int i = 0; texelFetch(triTable, ivec2(i, cube_index), 0).r != -1; i += 3){
        vec4 vert_a = vertices[texelFetch(triTable, ivec2(i, cube_index), 0).r];
        vec4 vert_b = vertices[texelFetch(triTable, ivec2(i+1,cube_index), 0).r];
        vec4 vert_c = vertices[texelFetch(triTable, ivec2(i+2,cube_index), 0).r];

        vec3 a = vert_a.xyz - vert_b.xyz;
        vec3 b = vert_c.xyz - vert_b.xyz;
        frag.normal = normalize(cross(a, b));

        gl_Position = mvp * vert_a;
        frag.position = gl_Position.xyz;
        frag.color = vec4(1.0,0,0,1.0);
        EmitVertex();

        gl_Position = mvp * vert_b;
        frag.position = gl_Position.xyz;
        frag.color = vec4(0,1.0,0,1.0);
        EmitVertex();

        gl_Position = mvp * vert_c;
        frag.position = gl_Position.xyz;
        frag.color = vec4(0,0,1.0,1.0);
        EmitVertex();
        EndPrimitive();
    }
}