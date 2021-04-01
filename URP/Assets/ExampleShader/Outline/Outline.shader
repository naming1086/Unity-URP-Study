Shader "Roystan/Outline Post Process"
{
	Properties
	{
		_MainTex("Main Texture",2D) = "white"{}
	}

    SubShader
    {
        Tags 
        { 
            "RenderPipeline"="UniversalRenderPipeline"
        }
        Cull Off ZWrite Off ZTest Always

		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		
		CBUFFER_START(UnityPerMaterial)
		float4 _MainTex_TexelSize;
		float4 _MainTex_ST;
		CBUFFER_END
		
		float4 _Color;
		float _Scale;
		float _DepthThreshold;
		float _DepthNormalThreshold;
		float _DepthNormalThresholdScale;
		float _NormalThreshold;
		float4x4 _ClipToView;

		TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
		TEXTURE2D(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);
		TEXTURE2D(_CameraDepthNormalsTexture);
        SAMPLER(sampler_CameraDepthNormalsTexture);

		struct a2v
        {
            float4 positionOS : POSITION;
        };

        struct v2f
        {
            float4 positionCS : SV_POSITION;
            float4 SSTexcoord : TEXCOORD;
            float3 viewSpaceDir : TEXCOORD2;
        };
		ENDHLSL

		Pass
		{
			HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                //o.positionCS = float4(i.positionOS.xy, 0.0, 1.0);
				o.SSTexcoord.xy = o.positionCS.xy*0.5+0.5*o.positionCS.w;
                #ifdef UNITY_UV_STARTS_AT_TOP
                o.SSTexcoord.y = o.positionCS.w - o.SSTexcoord.y;
                #endif
                o.SSTexcoord.zw = o.positionCS.zw;

				o.viewSpaceDir = mul(_ClipToView, o.positionCS).xyz;
                
				return o;
            }

			float4 alphaBlend(float4 top, float4 bottom)
			{
				float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
				float alpha = top.a + bottom.a * (1 - top.a);

				return float4(color, alpha);
			}

            half4 frag(v2f i):SV_Target
            {
				float2 SSUV = i.SSTexcoord.xy/i.SSTexcoord.w;//在片元里进行透除

				float halfScaleFloor = floor(_Scale * 0.5);
				float halfScaleCeil = ceil(_Scale * 0.5);

				// Sample the pixels in an X shape, roughly centered around i.texcoord.
				// As the _CameraDepthTexture and _CameraNormalsTexture default samplers
				// use point filtering, we use the above variables to ensure we offset
				// exactly one pixel at a time.
				float2 bottomLeftUV = SSUV - float2(_MainTex_TexelSize.x, _MainTex_TexelSize.y) * halfScaleFloor;
				float2 topRightUV = SSUV + float2(_MainTex_TexelSize.x, _MainTex_TexelSize.y) * halfScaleCeil;  
				float2 bottomRightUV = SSUV + float2(_MainTex_TexelSize.x * halfScaleCeil, -_MainTex_TexelSize.y * halfScaleFloor);
				float2 topLeftUV = SSUV + float2(-_MainTex_TexelSize.x * halfScaleFloor, _MainTex_TexelSize.y * halfScaleCeil);

				float3 normal0 = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, bottomLeftUV).rgb;
				float3 normal1 = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, topRightUV).rgb;
				float3 normal2 = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, bottomRightUV).rgb;
				float3 normal3 = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, topLeftUV).rgb;

				float depth0 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, bottomLeftUV).r;
				float depth1 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, topRightUV).r;
				float depth2 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, bottomRightUV).r;
				float depth3 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, topLeftUV).r;

				// Transform the view normal from the 0...1 range to the -1...1 range.
				float3 viewNormal = normal0 * 2 - 1;
				float NdotV = 1 - dot(viewNormal, -i.viewSpaceDir);

				// Return a value in the 0...1 range depending on where NdotV lies 
				// between _DepthNormalThreshold and 1.
				float normalThreshold01 = saturate((NdotV - _DepthNormalThreshold) / (1 - _DepthNormalThreshold));
				// Scale the threshold, and add 1 so that it is in the range of 1..._NormalThresholdScale + 1.
				float normalThreshold = normalThreshold01 * _DepthNormalThresholdScale + 1;

				// Modulate the threshold by the existing depth value;
				// pixels further from the screen will require smaller differences
				// to draw an edge.
				float depthThreshold = _DepthThreshold * depth0 * normalThreshold;

				float depthFiniteDifference0 = depth1 - depth0;
				float depthFiniteDifference1 = depth3 - depth2;
				// edgeDepth is calculated using the Roberts cross operator.
				// The same operation is applied to the normal below.
				// https://en.wikipedia.org/wiki/Roberts_cross
				float edgeDepth = sqrt(pow(depthFiniteDifference0, 2) + pow(depthFiniteDifference1, 2)) * 100;
				edgeDepth = edgeDepth > depthThreshold ? 1 : 0;

				float3 normalFiniteDifference0 = normal1 - normal0;
				float3 normalFiniteDifference1 = normal3 - normal2;
				// Dot the finite differences with themselves to transform the 
				// three-dimensional values to scalars.
				float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));
				edgeNormal = edgeNormal > _NormalThreshold ? 1 : 0;

				float edge = max(edgeDepth, edgeNormal);

				float4 edgeColor = float4(_Color.rgb, _Color.a * edge);

				float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, SSUV);

				return alphaBlend(edgeColor, color);
            }
            ENDHLSL
		}
    }
}