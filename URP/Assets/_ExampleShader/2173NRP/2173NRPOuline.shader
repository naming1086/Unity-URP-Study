Shader "2173NRP/Ouline"
{
    Properties
    {
		_OutlineWidth ("Outline Width", Range(0.01, 1)) = 0.24
        _OutLineColor ("OutLine Color", Color) = (0.5,0.5,0.5,1)
    }
    SubShader
    {
        Tags 
        { 
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Opaque" 
        }
		
		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		
		CBUFFER_START(UnityPerMaterial)
		float _OutlineWidth;
		float4 _OutLineColor;
		CBUFFER_END
		
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

		ENDHLSL
		
		Pass
		{
			NAME"MainPass"
			Tags
			{
				"LightMode"="UniversalForward"
			}
			
			Cull Back
					
			HLSLPROGRAM
			#pragma vertex vert
            #pragma fragment frag

			v2f vert(a2v i)
			{
				v2f o;
				o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
				return o;
			};
			
			half4 frag(v2f i): SV_TARGET 
			{
				return half4(1,1,1,1);
			};		
			ENDHLSL
		}

		
		Pass
		{
			NAME"OutlinePass"
			
			Cull Front
				
			HLSLPROGRAM
			#pragma vertex vert
            #pragma fragment frag
			
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
				pos.xy += 0.01 * _OutlineWidth * ndcNormal.xy*i.vertColor.a;//顶点色a通道控制粗细
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
