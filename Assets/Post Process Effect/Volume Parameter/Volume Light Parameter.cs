using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[System.Serializable, VolumeComponentMenu("Custom/VolumeLight")]
public class VolumeLightParameter : VolumeComponent, IPostProcessComponent
{
    [Header("BLoom Settings")]
    //定义shader要用的参数
    public FloatParameter intensity = new FloatParameter(0.9f, true);
    public MaterialParameter volumeLightParameter = new MaterialParameter(default, false);

    public bool IsActive()
    {
        return true;
    }

    public bool IsTileCompatible()
    {
        return false;
    }
}
