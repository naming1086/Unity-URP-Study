Shader "Roystan/Toon/Water"
{
    Properties
    {	
        // 当水面最浅时，水的颜色
        _DepthGradientShallow("Depth Gradient Shallow", Color) = (0.325, 0.807, 0.971, 0.725)

        // 当水面最深的时候，水的颜色
        _DepthGradientDeep("Depth Gradient Deep", Color) = (0.086, 0.407, 1, 0.749)

        // 水面下的最大深度，低于该值水面颜色不在发送变换
        _DepthMaxDistance("Depth Maximum Distance", Float) = 1

        // 渲染物体相交于表面所产生的泡沫颜色。
        _FoamColor ("Foam Color", Color) = (1, 1, 1, 1)
        
        // 用来产生波浪的噪声纹理。
        _SurfaceNoise ("Surface Noise", 2D) = "white" { }

        // 用于控制噪音滚动速度
        _SurfaceNoiseScroll ("Surface Noise Scroll Amount", Vector) = (0.03, 0.03, 0, 0)
        
        // 截止阈值，用于控制漂浮泡沫数量
        _SurfaceNoiseCutoff ("Surface Noise Cutoff", Range(0, 1)) = 0.777
        
        // 这个纹理的红色和绿色通道用来抵消噪声纹理，从而在波中产生失真。
        _SurfaceDistortion ("Surface Distortion", 2D) = "white" { }
        
        // 用这个值乘以失真。
        _SurfaceDistortionAmount ("Surface Distortion Amount", Range(0, 1)) = 0.27
        
        // 控制水面以下的距离将有助于渲染泡沫。
        _FoamMaxDistance ("Foam Maximum Distance", Float) = 0.4
        _FoamMinDistance ("Foam Minimum Distance", Float) = 0.04
        
        ///_FoamDistance ("Foam Distance", Float) = 0.4
    }
    SubShader
    {
        Tags 
		{ 
            "RenderPipeline"="UniversalPipeline"
            "RenderType" = "Opaque"
		}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        
        CBUFFER_START(UnityPerMaterial)
        float4 _SurfaceNoise_ST;
        float4 _SurfaceDistortion_ST;

        float4 _DepthGradientShallow;
        float4 _DepthGradientDeep;
        float4 _FoamColor;

        float _DepthMaxDistance;
        float _FoamMaxDistance;
        float _FoamMinDistance;

        float _SurfaceNoiseCutoff;
        float _SurfaceDistortionAmount;
        
        float2 _SurfaceNoiseScroll;
        
        /// float _FoamDistance;

        CBUFFER_END

        // 声明深度法线纹理，注意该名称是指定的
        TEXTURE2D(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);
        TEXTURE2D(_CameraDepthNormalsTexture);
        SAMPLER(sampler_CameraDepthNormalsTexture);
        // 水波噪声纹理
        TEXTURE2D(_SurfaceNoise);
        SAMPLER(sampler_SurfaceNoise);
        // 漂浮失真纹理
        TEXTURE2D(_SurfaceDistortion);
        SAMPLER(sampler_SurfaceDistortion);

        struct a2f
        {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD0;
            float3 normalOS: NORMAL;
        };

        struct v2f
        {
            float4 positionCS : SV_POSITION;
            float2 noiseUV: TEXCOORD0;
            float2 distortUV: TEXCOORD1;
            float4 screenPosition: TEXCOORD2;
            float3 viewNormal: NORMAL;
        };

        ENDHLSL

        Pass
        {
            Tags 
            { 
                "LightMode" = "UniversalForward" 
                "Queue" = "Transparent" 
            }
            Blend SrcAlpha OneMinusSrcAlpha

			HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #define SMOOTHSTEP_AA 0.01

            v2f vert (a2f i)
            {
                v2f o;

                //ZERO_INITIALIZE(v2f, o);

                // 模型空间转齐次裁剪空间
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                // 计算顶点在着色器中的屏幕空间位置
                o.screenPosition = ComputeScreenPos(o.positionCS);
                // 泡沫噪声纹理
                o.noiseUV = TRANSFORM_TEX(i.texcoord, _SurfaceNoise);
                // 漂浮失真纹理
                o.distortUV = TRANSFORM_TEX(i.texcoord, _SurfaceDistortion);

                // 水面在视角空间的法线纹理
                // o.viewNormal = COMPUTE_VIEW_NORMAL;
                o.viewNormal = normalize(mul((float3x3)UNITY_MATRIX_IT_MV, i.normalOS));
                return o;
            }
            
            // 解码深度
            inline float DecodeFloatRG(float2 enc)
            {
                float2 kDecodeDot = float2(1.0, 1 / 255.0);
                return dot(enc, kDecodeDot);
            }
            
            // 解码法线
            float3 DecodeNormal(float4 enc)
            {
                float kScale = 1.7777;
                float3 nn = enc.xyz * float3(2 * kScale, 2 * kScale, 0) + float3(-kScale, -kScale, 1);
                float g = 2.0 / dot(nn.xyz, nn.xyz);
                float3 n;
                n.xy = g * nn.xy;
                n.z = g - 1;
                return n;
            }

            //inline void DecodeDepthNormal(float4 enc, out float depth, out float3 normal)
            //{
            //    depth = DecodeFloatRG(enc.zw);
            //    normal = DecodeNormal(enc);
            //}

            //混合两种颜色使用相同的算法，我们的着色器使用混合屏幕。这通常被称为“普通混合”，类似于Photoshop等软件如何混合两个图层。
            float4 alphaBlend(float4 top, float4 bottom)
            {
                float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
                float alpha = top.a + bottom.a * (1 - top.a);
                
                return float4(color, alpha);
            }

            float4 frag (v2f i) : SV_Target
            {
                //--1.处理深度法线纹理
                // 采样法线深度纹理（xy/w将坐标从正交投影转换为透视投影）
                float4 sampleDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_CameraDepthTexture,i.screenPosition.xy / i.screenPosition.w);
                float4 sampleDepthNormal = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture,sampler_CameraDepthNormalsTexture,i.screenPosition.xy / i.screenPosition.w);
	            float depth = DecodeFloatRG(sampleDepth.zw);
                float3 normal = DecodeNormal(sampleDepth);
 
                //输出深度，从深度法线纹理中获取到的深度亮度值相比直接从深度纹理不够高，*1000以提升亮度
                depth = depth * 1000;
                // 水的表面和它背后的物体之间的距离，以单位表示。
                float depthDifference = depth - i.screenPosition.w;
                //return depthDifference;
                
                //--2.绘制颜色
                // 根据深度插值水的颜色。
                float waterDepthDifference01 = saturate(depthDifference / _DepthMaxDistance);
                float4 waterColor = lerp(_DepthGradientShallow, _DepthGradientDeep, waterDepthDifference01);
                //return waterColor;

                //--3.通过噪声绘制泡沫
                // 通过噪声纹理获取表面的波浪
                //float surfaceNoiseSample = SAMPLE_TEXTURE2D(_SurfaceNoise, sampler_SurfaceNoise, i.noiseUV).r;
                //return waterColor + surfaceNoiseSample;

                //--6.通过偏移来做泡沫漂浮动画
                /// float2 noiseUV = float2(i.noiseUV.x + _Time.y * _SurfaceNoiseScroll.x, i.noiseUV.y + _Time.y * _SurfaceNoiseScroll.y);
                /// float surfaceNoiseSample = SAMPLE_TEXTURE2D(_SurfaceNoise, sampler_SurfaceNoise, noiseUV).r;
                
                //--7.通过失真纹理加强泡沫左右漂浮效果
                float2 distortSample = (SAMPLE_TEXTURE2D(_SurfaceDistortion, sampler_SurfaceDistortion, i.distortUV).xy * 2 - 1) * _SurfaceDistortionAmount;
                // 通过噪声纹理获取表面的波浪
                float2 noiseUV = float2((i.noiseUV.x + _Time.y * _SurfaceNoiseScroll.x) + distortSample.x, (i.noiseUV.y + _Time.y * _SurfaceNoiseScroll.y) + distortSample.y);
                float surfaceNoiseSample = SAMPLE_TEXTURE2D(_SurfaceNoise, sampler_SurfaceNoise, noiseUV).r;
                
                //--4.通过阈值来控制泡沫数量
                /// 通过阈值来控制漂浮泡沫数量
                ///  float surfaceNoise = surfaceNoiseSample > _SurfaceNoiseCutoff ? 1: 0;
                ///  return waterColor + surfaceNoise;
                
                //--6.通过比对法线来实现物体周围的泡沫
                // 比对所有物体的法线与水平面法线来获取物体的边缘
                float3 normalDot = saturate(dot(normal, i.viewNormal));
                //return float4(normal,1);
                float foamDistance = lerp(_FoamMaxDistance, _FoamMinDistance, normalDot.x);
                float foamDepthDifference01 = saturate(depthDifference / foamDistance);
                
                //--5.通过深度阈值来控制边缘泡沫
                // 通过深度来控制泡沫数量，来绘制边缘泡沫
                ///float foamDepthDifference01 = saturate(depthDifference / _FoamDistance);
                float surfaceNoiseCutoff = foamDepthDifference01 * _SurfaceNoiseCutoff;
                // 通过阈值来控制漂浮泡沫数量
                ///float surfaceNoise = surfaceNoiseSample > surfaceNoiseCutoff ? 1: 0;
                ///return waterColor + surfaceNoise;
                
                //--8.优化抗锯齿
                float surfaceNoise = smoothstep(surfaceNoiseCutoff - SMOOTHSTEP_AA, surfaceNoiseCutoff + SMOOTHSTEP_AA, surfaceNoiseSample);
                
                //--7.使用自定义混合方式改进泡沫颜色
                float4 surfaceNoiseColor = _FoamColor;
                surfaceNoiseColor.a *= surfaceNoise;
                return alphaBlend(surfaceNoiseColor, waterColor);
            }
            ENDHLSL
        }
    }
}