
#ifdef DISTANT_HORIZONS
#define LOD_RENDERER
#define lodNearPlane dhNearPlane
#define lodFarPlane dhFarPlane

uniform int dhRenderDistance;
#define lodRenderDistance dhRenderDistance

#define lodProjection dhProjection
#define lodProjectionInverse dhProjectionInverse
#define lodPreviousProjection dhPreviousProjection


#define lodDepthTex dhDepthTex
#define lodDepthTex0 dhDepthTex0
#define lodDepthTex1 dhDepthTex1

#endif

#ifdef VOXY
#define LOD_RENDERER
#define lodNearPlane 16
#define lodFarPlane 48000

uniform int vxRenderDistance;
#define lodRenderDistance 16*vxRenderDistance

#define lodProjection vxProj
#define lodProjectionInverse vxProjInv
#define lodPreviousProjection vxProjPrev

#define lodDepthTex vxDepthTexTrans
#define lodDepthTex0 vxDepthTexTrans
#define lodDepthTex1 vxDepthTexOpaque

#define lodModelView vxModelView
#define lodModelViewInverse vxModelViewInv

#define lodPreviousModelView vxModelViewPrev
#define lodPreviousProjection vxViewProjPrev

#endif
