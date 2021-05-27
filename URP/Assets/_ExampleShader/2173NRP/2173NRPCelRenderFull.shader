Shader "2173NRP/2173NRPCelRenderFull"
{
    Properties
    {
		_MainTex ("MainTex", 2D) = "white" {}
        _IlmTex ("IlmTex", 2D) = "white" {}

		[Space(20)]
		_MainColor("Main Color", Color) = (1,1,1)
		_ShadowColor ("Shadow Color", Color) = (0.7, 0.7, 0.7)
		_ShadowSmooth("Shadow Smooth", Range(0, 0.03)) = 0.002
		_ShadowRange ("Shadow Range", Range(0, 1)) = 0.6

		[Space(20)]
		_SpecularColor("Specular Color", Color) = (1,1,1)
		_SpecularRange ("Specular Range",  Range(0, 1)) = 0.9
        _SpecularMulti ("Specular Multi", Range(0, 1)) = 0.4
		_SpecularGloss("Sprecular Gloss", Range(0.001, 8)) = 4

		[Space(20)]
		_RimColor ("Rim Color", Color) = (1,1,1)
		_RimMin ("Rim Min", Range(0, 1)) = 0
		_RimMax ("Rim Max", Range(0, 1)) = 0
		_RimSmooth ("Rim Smooth", Range(0, 1)) = 0

		[Space]
		_ShadowThreshold("Shadow Threshold", float) = 0.1
		_SpecularIntensity("Specular Intensity", float) = 0.1
		_SpecularRangeMask("Specular Range Mask", float) = 0.1

		[Space(20)]
		_OutlineWidth ("Outline Width", Range(0, 1)) = 0.24
        _OutLineColor ("OutLine Color", Color) = (0.5,0.5,0.5,1)
    }
    SubShader
    {
		Tags
		{
			"RenderPipeline" = "UniversalRenderPipeline"
			"RenderType" = "Opaque"
		}

        HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

		CBUFFER_START(UnityPerMaterial)
		float4 _MainTex_ST;
		float4 _IlmTex_ST;
		float4 _MainColor;
		float4 _ShadowColor;
		half _ShadowRange;
		half _ShadowSmooth;

        float4 _SpecularColor;
        float _SpecularRange;
        float _SpecularMulti;
        float _SpecularGloss;

		float4 _RimColor;
		float _RimMin;
		float _RimMax;
		float _RimSmooth;

		float _ShadowThreshold;
		float _SpecularIntensity;
		float _SpecularRangeMask;
	

		float _OutlineWidth;
		float4 _OutLineColor;
		CBUFFER_END

        TEXTURE2D(_MainTex);
		SAMPLER(sampler_MainTex);		
        TEXTURE2D(_IlmTex);
		SAMPLER(sampler_IlmTex);

        ENDHLSL

        Pass
        {
			NAME"MainPass"
			Tags
			{
				"LightMode" = "UniversalForward"
			}

			Cull Back

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

            struct a2v
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;	
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2; 
			};

            v2f vert (a2v v)
            {
				v2f o = (v2f)0;
				o.pos = TransformObjectToHClip(v.vertex.xyz);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.worldNormal = TransformObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				return o;
            }

            half4 frag (v2f i) : SV_Target
            {
				half4 col = 0;
				half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, i.uv);
				//half4 ilmTex = SAMPLE_TEXTURE2D (_IlmTex,sampler_IlmTex, i.uv);
				half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
				half3 worldNormal = normalize(i.worldNormal);

				Light myLight = GetMainLight();
				half3 worldLightDir = normalize(myLight.direction.xyz);

				half3 diffuse = 0;
				half halfLambert = dot(worldNormal, worldLightDir) * 0.5 + 0.5;
				//half threshold = (halfLambert + ilmTex.g) * 0.5;
				half threshold = (halfLambert + _ShadowThreshold) * 0.5;
				half ramp = saturate(_ShadowRange  - threshold); 
				ramp =  smoothstep(0, _ShadowSmooth, ramp);
				diffuse = lerp(_MainColor, _ShadowColor, ramp);
				diffuse *= mainTex.rgb;

				half3 specular = 0;
				half3 halfDir = normalize(worldLightDir + viewDir);
				half NdotH = max(0, dot(worldNormal, halfDir));
				half SpecularSize = pow(NdotH, _SpecularGloss);
				//half specularMask = ilmTex.b;
				half specularMask = _SpecularRangeMask;
				if (SpecularSize >= 1 - specularMask * _SpecularRange)
				{
					//specular = _SpecularMulti * (ilmTex.r) * _SpecularColor;
					specular = _SpecularMulti * _SpecularIntensity * _SpecularColor;
				}

				//half f =  1.0 - saturate(dot(viewDir, worldNormal));
				//half3 rimColor = f * _RimColor.rgb *  _RimColor.a;

				// 卡通渲染中，边缘光的过度通常会比较硬
				half f =  1.0 - saturate(dot(viewDir, worldNormal));
				half rim = smoothstep(_RimMin, _RimMax, f);
				rim = smoothstep(0, _RimSmooth, rim);
				half3 rimColor = rim * _RimColor.rgb *  _RimColor.a;

				col.rgb = (diffuse + specular + rimColor) * myLight.color.rgb;
				return col;
            }
            ENDHLSL
        }

		Pass
		{
			NAME"OutlinePass"

			Cull Front

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			struct a2v
			{
				float4 positionOS : POSITION;
				float3 normal : NORMAL;
				float4 vertColor : COLOR;
				float4 tangent : TANGENT;
			};

			struct v2f
			{
				float4 positionCS : SV_POSITION;
				float3 vertColor : COLOR;
			};

			v2f vert(a2v i)
			{
				v2f o;
				//o.positionCS = TransformObjectToHClip(float3(i.positionOS.xyz + i.normal * _OutlineWidth * 0.1));//顶点沿着法线方向外扩,世界空间小，宽度会随摄像机变化

				// 将法线外扩的大小调整为使用NDC空间的距离进行外扩
				float4 pos = TransformObjectToHClip(i.positionOS.xyz);
				float3 viewNormal = mul((float3x3)UNITY_MATRIX_IT_MV, i.tangent.xyz);//观察空间法线,使用切线数据作为外扩数据
				float3 ndcNormal = normalize(TransformWViewToHClip(viewNormal.xyz)) * pos.w;//将法线变换到裁剪空间

				// 因为NDC空间的xy是范围是[0,1]，且窗口分辨率不是1比1，所以直接用NDC空间的距离外扩，不能适配宽屏窗口;
				// 所以需要根据窗口的宽高比再进行修正。这里再对描边进行修改
				// 将近裁剪面右上角位置的顶点变换到观察空间
				float4 nearUpperRight = mul(unity_CameraInvProjection, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));
				// 求得屏幕宽高比
				float aspect = abs(nearUpperRight.y / nearUpperRight.x);

				ndcNormal.x *= aspect;
				pos.xy += 0.01 * _OutlineWidth * ndcNormal.xy * i.vertColor.a;//顶点色a通道控制粗细
				o.positionCS = pos;
				o.vertColor = i.vertColor.rgb;
				return o;
			};

			half4 frag(v2f i) : SV_TARGET
			{
				return half4(_OutLineColor * i.vertColor, 0);
			};

			ENDHLSL
		}
    }
}
