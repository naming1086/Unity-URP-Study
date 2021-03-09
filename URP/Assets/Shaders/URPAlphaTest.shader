Shader"URP/URPAlphaTest"
{
	Properties
	{
		_MainTex("MainTex",2D)="white"{}
		_BaseColor("BaseColor",Color)=(1,1,1,1)
		_Cutoff("Cutoff",float)=1
		[HDR]_BurnColor("BurnColor",Color)=(2.5,1,1,1)//灼烧光的颜色
	}

	SubShader
	{
		Tags
		{
			"RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="TransparentCutout" 
			"Queue"="AlphaTest"
		}

		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

		CBUFFER_START(UnityPerMaterial)
		float4 _MainTex_ST;
		half4 _BaseColor;
		float _Cutoff;
		half4 _BurnColor;
		CBUFFER_END

		TEXTURE2D(_MainTex);
		SAMPLER(sampler_MainTex);

		struct a2v
		{
			float4 positionOS:POSITION;
			float4 normalOS:NORMAL;
			float2 texcoord:TEXCOORD;
		};
		struct v2f
		{
			float4 positionCS:SV_POSITION;
			float2 texcoord:TEXCOORD;
		};
		ENDHLSL

		Pass
		{
			Tags
			{
				"LightMode"="UniversalForward"
			}

			HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

			v2f vert(a2v i)
			{
				v2f o;
				o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
				o.texcoord=TRANSFORM_TEX(i.texcoord,_MainTex);
				return o;
			}

			half4 frag(v2f i):SV_Target
			{
				half4 tex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord)*_BaseColor;
				//clip是对参数里低于0的部分舍弃掉
				//step(a,b) b >= a ? 1:0
				//这里减去0.01是因为clip对0是还会保留 所以要减去0.01让本身为0的部分被抛弃
				clip(step(_Cutoff,tex.r)-0.01);
				//lerp一下灼烧色和原色+0.1是控制灼烧区域范围
				tex=lerp(tex,_BurnColor,step(tex.r,saturate(_Cutoff+0.1)));
				return tex;
			}
			ENDHLSL
		}
	}
}
