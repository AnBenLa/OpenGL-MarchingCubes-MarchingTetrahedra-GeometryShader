#version 430

in fData
{
	vec3 position;
    vec3 normal;
    vec4 color;
}frag;

out vec4 out_color;

uniform float light_ambient_strength;
uniform vec3 light_diffuse_color;
uniform vec3 light_specular_color;
uniform vec3 light_position;
uniform vec3 camera_position;

uniform float shininess;

void main(){
    
    vec3 light_dir = normalize(light_position - frag.position);
    vec3 view_dir = normalize(camera_position - frag.position);

    float attenuation_factor = 1.0f / (1 + pow(length(light_dir), 2));
    vec3 diffuse = attenuation_factor * light_diffuse_color * frag.color.rgb * max(dot(light_dir, frag.normal), 0.0);

    vec3 ambient = frag.color.rgb*light_ambient_strength;

    vec3 halfvector = normalize(view_dir + light_dir);
    vec3 specular = attenuation_factor * light_specular_color * frag.color.rgb * pow(max(dot(halfvector, frag.normal), 0.0),shininess);

    out_color = vec4(clamp(ambient+(diffuse+specular),0.0,1.0), 1.0);
    out_color = frag.color;
}