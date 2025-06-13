// From http://www.redblobgames.com/x/1730-terrain-shader-experiments/
// Copyright 2017 Red Blob Games <redblobgames@gmail.com>
// License: Apache v2.0 <http://www.apache.org/licenses/LICENSE-2.0.html>

/*

This code is a mess in part because it was originally part of
some experiments for a different purpose. Sorry.

*/

'use strict';
const regl = createREGL({canvas: "#regl-canvas"});

let UNIFORMS = {
    u_seed: 0.0,
    u_bias: 0.0,
    u_amplitude: 1.0,
    u_wavelength: 0.35,
    u_blur: 0.0,
};

function makeRenderer(colorShader) {
    const radius = 1.0;
    let a_position = [];
    for (let dir = 0; dir < 6; dir++) {
        let angle0 = dir/6 * 2*Math.PI;
        let angle1 = (dir+1)/6 * 2*Math.PI;
        a_position.push([0, 0],
                        [radius * Math.cos(angle0), radius * Math.sin(angle0)],
                        [radius * Math.cos(angle1), radius * Math.sin(angle1)]);
    }
    let a_color = a_position.map(
        (_, i) => (i % 3 === 0)? [0.7, 0.6, 0.9] : (i % 6 < 3)? [0.53, 0.5, 0.5] : [0.43, 0.4, 0.4]);
    let a_color0 = a_color.map((_, i) => a_color[3*((i / 3) | 0)]);
    let a_color1 = a_color.map((_, i) => a_color[3*((i / 3) | 0) + 1]);
    let a_color2 = a_color.map((_, i) => a_color[3*((i / 3) | 0) + 2]);
    let a_barycentric = a_position.map(
        (_, i) => [i % 3 === 0, i % 3 === 1, i % 3 === 2]);

    return regl({
        frag: `precision highp float;` +
            MORGAN_MCGUIRE_NOISE + `
uniform float u_amplitude, u_wavelength, u_bias, u_seed, u_blur;
varying vec3 v_color0, v_color1, v_color2;
varying vec3 v_barycentric;
varying vec2 v_position;

void main() {
  vec3 color = v_color0 * v_barycentric.r + v_color1 * v_barycentric.g + v_color2 * v_barycentric.b;
` + colorShader + `
  gl_FragColor = vec4(color, 1);
}
`,

        vert: `
precision highp float;
attribute vec2 a_position;
attribute vec3 a_color0, a_color1, a_color2;
attribute vec3 a_barycentric;
varying vec3 v_color0, v_color1, v_color2;
varying vec3 v_barycentric;
varying vec2 v_position;
void main() {
  v_color0 = a_color0;
  v_color1 = a_color1;
  v_color2 = a_color2;
  v_barycentric = a_barycentric;
  v_position = a_position;
  gl_Position = vec4(a_position, 0, 1);
}
`,
        
        attributes: {a_position, a_color0, a_color1, a_color2, a_barycentric},
        uniforms: {
            u_amplitude: regl.prop('u_amplitude'),
            u_wavelength: regl.prop('u_wavelength'),
            u_bias: regl.prop('u_bias'),
            u_seed: regl.prop('u_seed'),
            u_blur: regl.prop('u_blur'),
        },
        count: a_position.length
    });
}

const BORDER = `
  color = color * smoothstep(0.0, 0.005, min(v_barycentric.r, min(v_barycentric.g, v_barycentric.b)));
`;

const NOISYCOLOR = `
  vec2 offset = v_position / u_wavelength;
  vec3 noisy = v_barycentric 
      + vec3(u_bias, 0, 0)
      + u_amplitude * vec3(NOISE(vec3(offset, v_color0.b + u_seed)), 
                              NOISE(vec3(offset, v_color1.b + u_seed)), 
                              NOISE(vec3(offset, v_color2.b + u_seed)));
  color = mix(v_color0, v_color1, smoothstep(u_blur, -u_blur, noisy.r - max(noisy.g, noisy.b)));
`;

function slider(param) {
    let input = document.getElementById(param);
    let text = document.createTextNode(UNIFORMS[param]);
    input.parentNode.insertBefore(text, input.nextSibling);
    input.value = UNIFORMS[param];
    input.addEventListener('input', () => {
        UNIFORMS[param] = input.valueAsNumber;
        text.nodeValue = input.value;
        redraw();
    });
}

let requestAnimationFrameId = null;
function redraw() {
    // NOTE: if I invoke the callback a second time on the same frame,
    // it will "glitch" by clearing the frame but *not* drawing the
    // triangles. So I need to make sure I don't already have a callback
    // queued up. I didn't notice this in Chrome; maybe it already limits
    // the number of slider events to one per frame.
    if (requestAnimationFrameId === null) {
        requestAnimationFrameId = requestAnimationFrame(() => {
            requestAnimationFrameId = null;
            regl.clear({color: [0.85, 0.85, 0.8, 1]});
            renderer(UNIFORMS);
        });
    }
}

let renderer = makeRenderer(NOISYCOLOR + BORDER);

slider('u_amplitude');
slider('u_wavelength');
slider('u_bias');
slider('u_seed');
slider('u_blur');
redraw();