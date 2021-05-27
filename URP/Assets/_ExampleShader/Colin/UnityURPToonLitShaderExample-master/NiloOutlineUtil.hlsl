// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

#ifndef Include_NiloOutlineUtil
#define Include_NiloOutlineUtil

// If your project has a faster way to get camera fov in shader, you can replace this slow function to your method.
// For example, you write cmd.SetGlobalFloat("_CurrentCameraFOV",cameraFOV) using a new RendererFeature in C#.
// For this tutorial shader, we will keep things simple and use this slower but convenient method to get camera fov
//���������Ŀ��һ������ķ���������ɫ���л�ȡ��Ӱ��������Խ����������滻Ϊ���ķ�����
//���磬��ʹ��C���е���RendererFeature��дcmd.SetGlobalFloat���� _ CurrentCameraFOV����cameraFOV����
//���ڱ��̵̳���ɫ�������ǽ�ʹ���鱣�ּ򵥣���ʹ�����ֽ���������ķ�������ȡ��������ӳ���
float GetCameraFOV()
{
    //https://answers.unity.com/questions/770838/how-can-i-extract-the-fov-information-from-the-pro.html
    float t = unity_CameraProjection._m11;
    float Rad2Deg = 180 / 3.1415;
    float fov = atan(1.0f / t) * 2.0 * Rad2Deg;
    return fov;
}
float ApplyOutlineDistanceFadeOut(float inputMulFix)
{
    //make outline "fadeout" if character is too small in camera's view
    //��������ͼ�е�����̫С����ʹ������������
    return saturate(inputMulFix);
}
float GetOutlineCameraFovAndDistanceFixMultiplier(float positionVS_Z)
{
    float cameraMulFix;
    if(unity_OrthoParams.w == 0)
    {
        ////////////////////////////////
        // Perspective camera case
        ////////////////////////////////

        // keep outline similar width on screen accoss all camera distance
        // ��������������ϣ�ʹ����������Ļ�ϵĿ�ȱ�������
        cameraMulFix = abs(positionVS_Z);

        // can replace to a tonemap function if a smooth stop is needed
        // �����Ҫƽ��ֹͣ�������滻Ϊɫ��ͼ����
        cameraMulFix = ApplyOutlineDistanceFadeOut(cameraMulFix);

        // keep outline similar width on screen accoss all camera fov
        // �������������ͷ����Ļ�ϵ������������
        cameraMulFix *= GetCameraFOV();       
    }
    else
    {
        ////////////////////////////////
        // Orthographic camera case
        ////////////////////////////////
        float orthoSize = abs(unity_OrthoParams.y);
        orthoSize = ApplyOutlineDistanceFadeOut(orthoSize);
        // 50��һ��ħ�����֣�����ƥ��͸��������������
        // 50 is a magic number to match perspective camera's outline width
        cameraMulFix = orthoSize * 50; 
    }

    // mul a const to make return result = default normal expand amount WS
    // ���constʹ���ؽ��=Ĭ������չ����WS
    return cameraMulFix * 0.00005; 
}
#endif

