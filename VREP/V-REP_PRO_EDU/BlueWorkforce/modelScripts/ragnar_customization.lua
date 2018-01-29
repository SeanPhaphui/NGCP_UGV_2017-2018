local bwUtils=require('bwUtils')
local utils=require('utils')

function removeFromPluginRepresentation()
    if bwfPluginLoaded then
        local data={}
        data.id=model
        simExtBwf_query('object_delete',data)
    end
end

function updatePluginRepresentation()
    if bwfPluginLoaded then
        local c=readInfo()
        local data={}
        data.id=model
        data.name=simGetObjectName(model)
        data.pos=simGetObjectPosition(model,-1)
        data.ypr=simGetObjectOrientation(model,-1)
        data.primaryArmLength=c.primaryArmLengthInMM/1000
        data.secondaryArmLength=c.secondaryArmLengthInMM/1000
        simExtBwf_query('ragnar_update',data)
    end
end

setFkMode=function()
    -- disable the platform positional constraints:
    simSetIkElementProperties(ikGroup,ikModeTipDummy,0)
    -- Set the driving joints into passive mode (not taken into account during IK resolution):
    simSetJointMode(fkDrivingJoints[1],sim_jointmode_passive,0)
    simSetJointMode(fkDrivingJoints[2],sim_jointmode_passive,0)
    simSetJointMode(fkDrivingJoints[3],sim_jointmode_passive,0)
    simSetJointMode(fkDrivingJoints[4],sim_jointmode_passive,0)
end

function getZPosition()
    return simGetObjectPosition(model,-1)[3]
end

function openFrame(open)
    local a=0
    if open then
        a=-math.pi
    end
    for i=1,3,1 do
        simSetJointPosition(frameOpenClose[i],a)
    end
end

function setFrameVisible(visible)
    local p=0
    if not visible then
        p=sim_modelproperty_not_collidable+sim_modelproperty_not_detectable+sim_modelproperty_not_dynamic+
          sim_modelproperty_not_measurable+sim_modelproperty_not_renderable+sim_modelproperty_not_respondable+
          sim_modelproperty_not_visible+sim_modelproperty_not_showasinsidemodel
    end
    simSetModelProperty(frameModel,p)
end

function setLowBeamsVisible(visible)
    for i=1,2,1 do
        if not visible then
            simSetObjectSpecialProperty(frameBeams[i],0)
            simSetObjectInt32Parameter(frameBeams[i],sim_objintparam_visibility_layer,0)
        else
            simSetObjectSpecialProperty(frameBeams[i],sim_objectspecialproperty_collidable+sim_objectspecialproperty_detectable_all+sim_objectspecialproperty_measurable+sim_objectspecialproperty_renderable)
            simSetObjectInt32Parameter(frameBeams[i],sim_objintparam_visibility_layer,1)
        end
    end
end

function isFrameOpen()
    return math.abs(simGetJointPosition(frameOpenClose[1]))<0.1
end

function getAvailableTrackingWindows()
    local l=simGetObjectsInTree(sim_handle_scene,sim_handle_all,0)
    local retL={}
    for i=1,#l,1 do
        local data=simReadCustomDataBlock(l[i],'XYZ_TRACKINGWINDOW_INFO')
        if data then
            retL[#retL+1]={simGetObjectName(l[i]),l[i]}
        end
    end
    return retL
end

function getAvailableDropLocations(returnMap)
    local l=simGetObjectsInTree(sim_handle_scene,sim_handle_all,0)
    local retL={}
    for i=1,#l,1 do
        local data1=simReadCustomDataBlock(l[i],'XYZ_LOCATION_INFO')
        local data2=simReadCustomDataBlock(l[i],'XYZ_BUCKET_INFO')
        if data1 or data2 then
            if returnMap then
                retL[simGetObjectName(l[i])]=l[i]
            else
                retL[#retL+1]={simGetObjectName(l[i]),l[i]}
            end
        end
    end
    return retL
end

function getDefaultInfoForNonExistingFields(info)
    if not info['version'] then
        info['version']=_MODELVERSION_
    end
    if not info['subtype'] then
        info['subtype']='ragnar'
    end
    if not info['primaryArmLengthInMM'] then
        info['primaryArmLengthInMM']=300
    end
    if not info['secondaryArmLengthInMM'] then
        info['secondaryArmLengthInMM']=550
    end
    if not info['maxVel'] then
        info['maxVel']=1
    end
    if not info['maxAccel'] then
        info['maxAccel']=1
    end
    if not info['dwellTime'] then
        info['dwellTime']=0.1
    end
    if not info['bitCoded'] then
        info['bitCoded']=0 -- 1=visualize trajectory, 2=frame open, 4=frame is visible,8= frame low beam visible, 64=enabled, 128=show statistics, 256=show ws, 512=show ws also during simulation, 1024=attach part to target via a force sensor, 2048=pick part without target in sight, 4096=ragnar in FK mode and idle, 8192=showGraph, 16384=reflectConfig
    end
    if not info['trackingTimeShift'] then
        info['trackingTimeShift']=0
    end
    if not info['algorithm'] then
        info['algorithm']=''
    end
    if not info['pickOffset'] then
        info['pickOffset']={0,0,0}
    end
    if not info['placeOffset'] then
        info['placeOffset']={0,0,0}
    end
    if not info['pickRounding'] then
        info['pickRounding']=0.05
    end
    if not info['placeRounding'] then
        info['placeRounding']=0.05
    end
    if not info['pickNulling'] then
        info['pickNulling']=0.005
    end
    if not info['placeNulling'] then
        info['placeNulling']=0.005
    end
    if not info['pickApproachHeight'] then
        info['pickApproachHeight']=0.1
    end
    if not info['placeApproachHeight'] then
        info['placeApproachHeight']=0.1
    end

    if not info['connectionIp'] then
        info['connectionIp']="127.0.0.1"
    end
    if not info['connectionPort'] then
        info['connectionPort']=19800
    end
    if not info['connectionTimeout'] then
        info['connectionTimeout']=1
    end
    if not info['connectionBufferSize'] then
        info['connectionBufferSize']=1000
    end
end

function readInfo()
    local data=simReadCustomDataBlock(model,'RAGNAR_CONF')
    if data then
        data=simUnpackTable(data)
    else
        data={}
    end
    getDefaultInfoForNonExistingFields(data)
    return data
end

function writeInfo(data)
    if data then
        simWriteCustomDataBlock(model,'RAGNAR_CONF',simPackTable(data))
    else
        simWriteCustomDataBlock(model,'RAGNAR_CONF','')
    end
end

function getLinkBLength(a,f)
    local tol=0.001 -- very small tolerance value to make sure the nominal robot has sizes a=300, b=550
    return 0.05*math.ceil((a*f-tol)/0.05)
end

function showHideWorkspace(show)
    local r,minZ=simGetObjectFloatParameter(workspace,sim_objfloatparam_objbbox_min_z)
    local r,maxZ=simGetObjectFloatParameter(workspace,sim_objfloatparam_objbbox_max_z)
    local s=maxZ-minZ
    local inf=readInfo()
    local primaryArmLengthInMM=inf['primaryArmLengthInMM']
    local a=primaryArmLengthInMM/1000+0.0005
    
    
    local d=3.569384*a -- 3.569384=1.0726/0.3005
    simScaleObject(workspace,d/s,d/s,d/s)

    local p={-0.00485*a/0.3005,-0.00176*a/0.3005,-0.48947*a/0.3005}
    simSetObjectPosition(workspace,sim_handle_parent,p)

    if show then
        simSetObjectInt32Parameter(workspace,sim_objintparam_visibility_layer,1)
    else
        simSetObjectInt32Parameter(workspace,sim_objintparam_visibility_layer,0)
    end
end

function isWorkspaceVisible()
    local c=readInfo()
    return simBoolAnd32(c['bitCoded'],256)>0
end

function adjustRobot()
    local inf=readInfo()
    local primaryArmLengthInMM=inf['primaryArmLengthInMM']
    local secondaryArmLengthInMM=inf['secondaryArmLengthInMM']

--    local a=0.2+((primaryArmLengthInMM-200)/50)*0.05+0.0005
    local a=primaryArmLengthInMM/1000+0.0005
    local b=secondaryArmLengthInMM/1000
 

    local c=0.025
    local x=math.sqrt(a*a-c*c)
    local upAdjust=x-math.sqrt(0.3005*0.3005-c*c) -- Initial lengths are 300.5 and 550.0 (not 300/550!)
    local downAdjust=b-0.55
    local dx=a*28/30
    local ddx=dx-0.28

---[[
    for i=1,4,1 do
        simSetJointPosition(upperArmAdjust[i],upAdjust)
    end

    for i=1,8,1 do
        simSetJointPosition(lowerArmAdjust[i],downAdjust)
    end


    for i=1,4,1 do
        simSetJointPosition(upperArmLAdjust[i],upAdjust*0.5)
    end

    for i=1,8,1 do
        simSetJointPosition(lowerArmLAdjust[i],downAdjust*0.5)
    end

    for i=1,2,1 do
        simSetJointPosition(frontAndRearCoverAdjust[i],ddx)
    end

    for i=1,3,1 do
        local h=middleCoverParts[i]
        local r,minY=simGetObjectFloatParameter(h,sim_objfloatparam_objbbox_min_y)
        local r,maxY=simGetObjectFloatParameter(h,sim_objfloatparam_objbbox_max_y)
        local s=maxY-minY
        local d=0.28+0.0122+ddx*2
        simScaleObject(h,1,d/s,1)
    end

    for i=1,2,1 do
        local h=middleCoverParts[3+i]
        local r,minZ=simGetObjectFloatParameter(h,sim_objfloatparam_objbbox_min_z)
        local r,maxZ=simGetObjectFloatParameter(h,sim_objfloatparam_objbbox_max_z)
        local s=maxZ-minZ
        local d=0.3391
        if a<0.18 then
            d=0.1187
        elseif a<0.23 then
            d=0.2204
        end
        simScaleObject(h,d/s,d/s,d/s)
    end


    for i=1,4,1 do
        local h=upperLinks[i]
        local r,minZ=simGetObjectFloatParameter(h,sim_objfloatparam_objbbox_min_z)
        local r,maxZ=simGetObjectFloatParameter(h,sim_objfloatparam_objbbox_max_z)
        local s=maxZ-minZ
        local d=0.242+upAdjust
        simScaleObject(h,1,1,d/s)
    end

    for i=1,8,1 do
        local h=lowerLinks[i]
        local r,minZ=simGetObjectFloatParameter(h,sim_objfloatparam_objbbox_min_z)
        local r,maxZ=simGetObjectFloatParameter(h,sim_objfloatparam_objbbox_max_z)
        local s=maxZ-minZ
        local r,minX=simGetObjectFloatParameter(h,sim_objfloatparam_objbbox_min_x)
        local r,maxX=simGetObjectFloatParameter(h,sim_objfloatparam_objbbox_max_x)
        local sx=maxX-minX
        local d=0.5+downAdjust
        local diam=0.01
        if d>=0.5 then
            diam=0.014
        end
        simScaleObject(h,diam/sx,diam/sx,d/s)
    end

    local p=simGetObjectPosition(ikTarget,model)

    relZPos=-a*2

    simSetObjectPosition(ikTarget,model,{p[1],p[2],relZPos})

    simHandleIkGroup(ikGroup)

    -- The frame:
    local nomS={0.9674,0.9674,0.9674,0.411,0.98509,0.98509,0.7094,0.7094}
    for i=1,4,1 do
        local h=frameBeams[i]
        local r,minY=simGetObjectFloatParameter(h,sim_objfloatparam_objbbox_min_y)
        local r,maxY=simGetObjectFloatParameter(h,sim_objfloatparam_objbbox_max_y)
        local s=maxY-minY
        local d=nomS[i]+ddx*2
        simScaleObject(h,1,d/s,1)
    end
    simSetJointPosition(frameJoints[1],ddx)
    simSetJointPosition(frameJoints[2],ddx)
--]]
end

function adjustHeight(z)
    local dz=z-1.36
    local nomS={0.9674,0.9674,0.9674,0.411,0.98509,0.98509,0.7094,0.7094}
    for i=5,8,1 do
        local h=frameBeams[i]
        local r,minZ=simGetObjectFloatParameter(h,sim_objfloatparam_objbbox_min_z)
        local r,maxZ=simGetObjectFloatParameter(h,sim_objfloatparam_objbbox_max_z)
        local s=maxZ-minZ
        local d=nomS[i]+dz
        simScaleObject(h,1,1,d/s)
    end
    local c=readInfo()


    simSetJointPosition(frameJoints[3],-dz)
    simSetJointPosition(frameJoints[4],-dz)
    simSetJointPosition(frameJoints[5],-dz)
    simSetJointPosition(frameJoints[6],-dz)
    local p=simGetObjectPosition(model,-1)
    simSetObjectPosition(model,-1,{p[1],p[2],z})

    for i=7,10,1 do
        simSetJointPosition(frameJoints[i],-dz*0.5)
    end
end

function getJointPositions(handles)
    local retTable={}
    for i=1,#handles,1 do
        retTable[i]=simGetJointPosition(handles[i])
    end
    return retTable
end

function setJointPositions(handles,positions)
    for i=1,#handles,1 do
        simSetJointPosition(handles[i],positions[i])
    end
end

function updateLinkLengthDisplay()
    if ui then
        local c=readInfo()
        simExtCustomUI_setLabelText(ui,1,'Primary arm length: '..string.format("%.0f",c['primaryArmLengthInMM'])..' mm')
        simExtCustomUI_setLabelText(ui,91,'Secondary arm length: '..string.format("%.0f",c['secondaryArmLengthInMM'])..' mm')
    end
end

function updateMovementParamDisplay()
    if ui then
        local c=readInfo()
        local sel=bwUtils.getSelectedEditWidget(ui)
        simExtCustomUI_setEditValue(ui,10,string.format("%.0f",c['maxVel']*1000),true)
        simExtCustomUI_setEditValue(ui,11,string.format("%.0f",c['maxAccel']*1000),true)
        simExtCustomUI_setEditValue(ui,12,string.format("%.3f",c['dwellTime']),true)
        simExtCustomUI_setEditValue(ui,13,string.format("%.3f",c['trackingTimeShift']),true)
        local off=c['pickOffset']
        simExtCustomUI_setEditValue(ui,1001,string.format("%.0f , %.0f , %.0f",off[1]*1000,off[2]*1000,off[3]*1000),true)
        off=c['placeOffset']
        simExtCustomUI_setEditValue(ui,1002,string.format("%.0f , %.0f , %.0f",off[1]*1000,off[2]*1000,off[3]*1000),true)
        simExtCustomUI_setEditValue(ui,1003,string.format("%.0f",c['pickRounding']*1000),true)
        simExtCustomUI_setEditValue(ui,1004,string.format("%.0f",c['placeRounding']*1000),true)
        simExtCustomUI_setEditValue(ui,1005,string.format("%.0f",c['pickNulling']*1000),true)
        simExtCustomUI_setEditValue(ui,1006,string.format("%.0f",c['placeNulling']*1000),true)
        simExtCustomUI_setEditValue(ui,1007,string.format("%.0f",c['pickApproachHeight']*1000),true)
        simExtCustomUI_setEditValue(ui,1008,string.format("%.0f",c['placeApproachHeight']*1000),true)
        bwUtils.setSelectedEditWidget(ui,sel)
    end
end

function setArmLength(primaryArmLengthInMM,secondaryArmLengthInMM)
    local allowedB={} -- in multiples of 50
    allowedB[200]={400,450}
    allowedB[250]={450,600}
    allowedB[300]={550,700}
    allowedB[350]={650,800}
    allowedB[400]={750,900}
    allowedB[450]={850,1000}
    allowedB[500]={900,1150}
    allowedB[550]={1000,1250}
    
    local allowedA={} -- in multiples of 50
    allowedA[400]={200,200}
    allowedA[450]={200,250}
    allowedA[500]={250,250}
    allowedA[550]={250,300}
    allowedA[600]={250,300}
    allowedA[650]={300,350}
    allowedA[700]={300,350}
    allowedA[750]={350,400}
    allowedA[800]={350,400}
    allowedA[850]={400,450}
    allowedA[900]={400,500}
    allowedA[950]={450,500}
    allowedA[1000]={450,550}
    allowedA[1050]={500,550}
    allowedA[1100]={500,550}
    allowedA[1150]={500,550}
    allowedA[1200]={550,550}
    allowedA[1250]={550,550}
    
    local c=readInfo()
    if primaryArmLengthInMM then
        -- We changed the primary arm length
        c['primaryArmLengthInMM']=primaryArmLengthInMM
        local allowed=allowedB[primaryArmLengthInMM]
        secondaryArmLengthInMM=c['secondaryArmLengthInMM']
        if secondaryArmLengthInMM<allowed[1] then
            secondaryArmLengthInMM=allowed[1]
        end
        if secondaryArmLengthInMM>allowed[2] then
            secondaryArmLengthInMM=allowed[2]
        end
        c['secondaryArmLengthInMM']=secondaryArmLengthInMM
    else
        -- We changed the secondary arm length
        c['secondaryArmLengthInMM']=secondaryArmLengthInMM
        local allowed=allowedA[secondaryArmLengthInMM]
        primaryArmLengthInMM=c['primaryArmLengthInMM']
        if primaryArmLengthInMM<allowed[1] then
            primaryArmLengthInMM=allowed[1]
        end
        if primaryArmLengthInMM>allowed[2] then
            primaryArmLengthInMM=allowed[2]
        end
        c['primaryArmLengthInMM']=primaryArmLengthInMM
    end
    writeInfo(c)
    modified=true
    adjustRobot()
    showHideWorkspace(isWorkspaceVisible())
    updateLinkLengthDisplay()
end

function sizeAChange_callback(ui,id,newVal)
    setArmLength(200+newVal*50,nil)
    local c=readInfo()
    simExtCustomUI_setSliderValue(ui,92,(c['secondaryArmLengthInMM']-400)/50,true)
end

function sizeBChange_callback(ui,id,newVal)
    setArmLength(nil,400+newVal*50)
    local c=readInfo()
    simExtCustomUI_setSliderValue(ui,2,(c['primaryArmLengthInMM']-200)/50,true)
end

function ZChange_callback(uiHandle,id,newValue)
    local c=readInfo()
    newValue=tonumber(newValue)
    local z=getZPosition()
    if newValue then
        newValue=newValue/1000
        if newValue<1.0 then newValue=1.0 end
        if newValue>3 then newValue=3 end
        if newValue~=z then
            z=newValue
            adjustHeight(newValue)
            modified=true
        end
    end
    simExtCustomUI_setEditValue(ui,77,string.format("%.0f",z*1000),true)
end

function velocityChange_callback(uiHandle,id,newValue)
    local c=readInfo()
    newValue=tonumber(newValue)
    if newValue then
        if newValue<1 then newValue=1 end
        if newValue>5000 then newValue=5000 end
        newValue=newValue/1000
        if newValue~=c['maxVel'] then
            c['maxVel']=newValue
            writeInfo(c)
            modified=true
        end
    end
    updateMovementParamDisplay()
end

function accelerationChange_callback(uiHandle,id,newValue)
    local c=readInfo()
    newValue=tonumber(newValue)
    if newValue then
        if newValue<1 then newValue=1 end
        if newValue>35000 then newValue=35000 end
        newValue=newValue/1000
        if newValue~=c['maxAccel'] then
            c['maxAccel']=newValue
            writeInfo(c)
            modified=true
        end
    end
    updateMovementParamDisplay()
end

function dwellTimeChange_callback(uiHandle,id,newValue)
    local c=readInfo()
    newValue=tonumber(newValue)
    if newValue then
        if newValue<0.01 then newValue=0.01 end
        if newValue>1 then newValue=1 end
        if newValue~=c['dwellTime'] then
            c['dwellTime']=newValue
            writeInfo(c)
            modified=true
        end
    end
    updateMovementParamDisplay()
end

function trackingTimeShiftChange_callback(uiHandle,id,newValue)
    local c=readInfo()
    newValue=tonumber(newValue)
    if newValue then
        if newValue<-1 then newValue=-1 end
        if newValue>1 then newValue=1 end
        if newValue~=c['trackingTimeShift'] then
            c['trackingTimeShift']=newValue
            writeInfo(c)
            modified=true
        end
    end
    updateMovementParamDisplay()
end

function pickOffsetChange_callback(ui,id,newVal)
    local c=readInfo()
    local i=1
    local t={0,0,0}
    for token in (newVal..","):gmatch("([^,]*),") do
        t[i]=tonumber(token)
        if t[i]==nil then t[i]=0 end
        t[i]=t[i]*0.001
        if t[i]>0.2 then t[i]=0.2 end
        if t[i]<-0.2 then t[i]=-0.2 end
        i=i+1
    end
    c['pickOffset']={t[1],t[2],t[3]}
    modified=true
    writeInfo(c)
    updateMovementParamDisplay()
end

function placeOffsetChange_callback(ui,id,newVal)
    local c=readInfo()
    local i=1
    local t={0,0,0}
    for token in (newVal..","):gmatch("([^,]*),") do
        t[i]=tonumber(token)
        if t[i]==nil then t[i]=0 end
        t[i]=t[i]*0.001
        if t[i]>0.2 then t[i]=0.2 end
        if t[i]<-0.2 then t[i]=-0.2 end
        i=i+1
    end
    c['placeOffset']={t[1],t[2],t[3]}
    modified=true
    writeInfo(c)
    updateMovementParamDisplay()
end

function pickRoundingChange_callback(uiHandle,id,newValue)
    local c=readInfo()
    newValue=tonumber(newValue)
    if newValue then
        if newValue<1 then newValue=1 end
        if newValue>500 then newValue=500 end
        newValue=newValue/1000
        if newValue~=c['pickRounding'] then
            c['pickRounding']=newValue
            writeInfo(c)
            modified=true
        end
    end
    updateMovementParamDisplay()
end

function placeRoundingChange_callback(uiHandle,id,newValue)
    local c=readInfo()
    newValue=tonumber(newValue)
    if newValue then
        if newValue<1 then newValue=1 end
        if newValue>200 then newValue=200 end
        newValue=newValue/1000
        if newValue~=c['placeRounding'] then
            c['placeRounding']=newValue
            writeInfo(c)
            modified=true
        end
    end
    updateMovementParamDisplay()
end


function pickNullingChange_callback(uiHandle,id,newValue)
    local c=readInfo()
    newValue=tonumber(newValue)
    if newValue then
        if newValue<1 then newValue=1 end
        if newValue>50 then newValue=50 end
        newValue=newValue/1000
        if newValue~=c['pickNulling'] then
            c['pickNulling']=newValue
            writeInfo(c)
            modified=true
        end
    end
    updateMovementParamDisplay()
end

function placeNullingChange_callback(uiHandle,id,newValue)
    local c=readInfo()
    newValue=tonumber(newValue)
    if newValue then
        if newValue<1 then newValue=1 end
        if newValue>50 then newValue=50 end
        newValue=newValue/1000
        if newValue~=c['placeNulling'] then
            c['placeNulling']=newValue
            writeInfo(c)
            modified=true
        end
    end
    updateMovementParamDisplay()
end

function pickApproachHeightChange_callback(uiHandle,id,newValue)
    local c=readInfo()
    newValue=tonumber(newValue)
    if newValue then
        if newValue<10 then newValue=10 end
        if newValue>500 then newValue=500 end
        newValue=newValue/1000
        if newValue~=c['pickApproachHeight'] then
            c['pickApproachHeight']=newValue
            writeInfo(c)
            modified=true
        end
    end
    updateMovementParamDisplay()
end

function placeApproachHeightChange_callback(uiHandle,id,newValue)
    local c=readInfo()
    newValue=tonumber(newValue)
    if newValue then
        if newValue<10 then newValue=10 end
        if newValue>500 then newValue=500 end
        newValue=newValue/1000
        if newValue~=c['placeApproachHeight'] then
            c['placeApproachHeight']=newValue
            writeInfo(c)
            modified=true
        end
    end
    updateMovementParamDisplay()
end

function visualizeWorkspaceClick_callback(uiHandle,id,newVal)
    local c=readInfo()
    c['bitCoded']=simBoolOr32(c['bitCoded'],256)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-256
    end
    modified=true
    writeInfo(c)
    showHideWorkspace(newVal>0)
end

function visualizeWorkspaceSimClick_callback(uiHandle,id,newVal)
    local c=readInfo()
    c['bitCoded']=simBoolOr32(c['bitCoded'],512)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-512
    end
    modified=true
    writeInfo(c)
end

function visualizeTrajectoryClick_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=simBoolOr32(c['bitCoded'],1)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-1
    end
    modified=true
    writeInfo(c)
end

function openFrameClick_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=simBoolOr32(c['bitCoded'],2)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-2
    end
    modified=true
    writeInfo(c)
    openFrame(newVal~=0)
end

function visibleFrameClick_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=simBoolOr32(c['bitCoded'],4)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-4
    end
    modified=true
    writeInfo(c)
    setFrameVisible(newVal~=0)
end

function visibleFrameLowBeamsClick_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=simBoolOr32(c['bitCoded'],8)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-8
    end
    modified=true
    writeInfo(c)
    setLowBeamsVisible(newVal~=0)
end

function enabledClicked_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=simBoolOr32(c['bitCoded'],64)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-64
    end
    modified=true
    writeInfo(c)
end

function showStatisticsClick_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=simBoolOr32(c['bitCoded'],128)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-128
    end
    modified=true
    writeInfo(c)
    if simGetSimulationState()~=sim_simulation_stopped then
        simCallScriptFunction("enableDisableStats_fromCustomizationScript@"..simGetObjectName(model),sim_scripttype_childscript,newVal~=0)
    end
end

function ragnarIsIdle_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=simBoolOr32(c['bitCoded'],4096)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-4096
    end
    modified=true
    writeInfo(c)
end

function attachPartClicked_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=simBoolOr32(c['bitCoded'],1024)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-1024
    end
    modified=true
    writeInfo(c)
end

function pickWithoutTargetClicked_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=simBoolOr32(c['bitCoded'],2048)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-2048
    end
    modified=true
    writeInfo(c)
end

function ip_callback(uiHandle,id,newValue)
    local c=readInfo()
    if c['connectionIp']~=newValue then
        c['connectionIp']=newValue
        modified=true
        writeInfo(c)
    end
    simExtCustomUI_setEditValue(ui,1200,c['connectionIp'],true)
end

function port_callback(uiHandle,id,newValue)
    local c=readInfo()
    newValue=tonumber(newValue)
    if newValue then
        if newValue<0 then newValue=0 end
        if newValue>65525 then newValue=65525 end
        if c['connectionPort']~=newValue then
            c['connectionPort']=newValue
            modified=true
            writeInfo(c)
        end
    end
    simExtCustomUI_setEditValue(ui,1201,string.format("%i",c['connectionPort']),true)
end

function timeout_callback(uiHandle,id,newValue)
    local c=readInfo()
    newValue=tonumber(newValue)
    if newValue then
        if newValue<0.01 then newValue=0.01 end
        if newValue>10 then newValue=10 end
        if c['connectionTimeout']~=newValue then
            c['connectionTimeout']=newValue
            modified=true
            writeInfo(c)
        end
    end
    simExtCustomUI_setEditValue(ui,1202,string.format("%.2f",c['connectionTimeout']),true)
end

function bufferSize_callback(uiHandle,id,newValue)
    local c=readInfo()
    newValue=tonumber(newValue)
    if newValue then
        if newValue<1 then newValue=1 end
        if newValue>10000 then newValue=10000 end
        if c['connectionBufferSize']~=newValue then
            c['connectionBufferSize']=newValue
            modified=true
            writeInfo(c)
        end
    end
    simExtCustomUI_setEditValue(ui,1203,string.format("%i",c['connectionBufferSize']),true)
end

function connect_callback()
    connect()
end

function pause_callback()
    paused=true
    updateEnabledDisabledItems()
    enableMouseInteractionsOnPlot(true)
    if plotUi then
        simExtCustomUI_setTitle(plotUi,simGetObjectName(model)..' (paused)',true)
    end
end

function resume_callback()
    paused=false
    updateEnabledDisabledItems()
    enableMouseInteractionsOnPlot(false)
    if plotUi then
        simExtCustomUI_setTitle(plotUi,simGetObjectName(model)..' (online)',true)
    end
end

function disconnect_callback()
    disconnect()
end

enableMouseInteractionsOnPlot=function(enable)
    if plotUi then
        simExtCustomUI_setMouseOptions(plotUi,1,enable,enable,enable,enable)
    end
end

function closePlot()
    if plotUi then
        local x,y=simExtCustomUI_getPosition(plotUi)
        previousPlotDlgPos={x,y}
        local x,y=simExtCustomUI_getSize(plotUi)
        previousPlotDlgSize={x,y}
        plotTabIndex=simExtCustomUI_getCurrentTab(plotUi,77)
        simExtCustomUI_destroy(plotUi)
        plotUi=nil
    end
end

function connect()
    if bwfPluginLoaded then
        connected=true
        updateEnabledDisabledItems()
        if utils.fastIdleLoop then
            utils.fastIdleLoop(true)
        else
            simSetInt32Parameter(sim_intparam_idle_fps,0)
        end
        local c=readInfo()

        if not plotUi and simBoolAnd32(c['bitCoded'],8192)>0 then
            local xml=[[<tabs id="77">
                    <tab title="Axes angles">
                    <plot id="1" max-buffer-size="100000" cyclic-buffer="false" background-color="25,25,25" foreground-color="150,150,150"/>
                    </tab>
                    <tab title="Axes errors">
                    <plot id="2" max-buffer-size="100000" cyclic-buffer="false" background-color="25,25,25" foreground-color="150,150,150"/>
                    </tab>
                    <tab title="Axes velocity">
                    <plot id="3" max-buffer-size="100000" cyclic-buffer="false" background-color="25,25,25" foreground-color="150,150,150"/>
                    </tab>
                    <tab title="Platform velocity">
                    <plot id="4" max-buffer-size="100000" cyclic-buffer="false" background-color="25,25,25" foreground-color="150,150,150"/>
                    </tab>
                </tabs>]]
            if not previousPlotDlgPos then
                previousPlotDlgPos="bottomRight"
            end
            plotUi=utils.createCustomUi(xml,simGetObjectName(model)..' (online)',previousPlotDlgPos,true,"closePlot",false,true,false,nil,previousPlotDlgSize)
            simExtCustomUI_setPlotLabels(plotUi,1,"Time (seconds)","degrees")
            if not plotTabIndex then
                plotTabIndex=0
            end
            simExtCustomUI_setCurrentTab(plotUi,77,plotTabIndex,true)

            local curveStyle=sim_customui_curve_style_line
            local scatterShape={scatter_shape=sim_customui_curve_scatter_shape_none,scatter_size=5,line_size=1}
            simExtCustomUI_addCurve(plotUi,1,sim_customui_curve_type_time,'axis1',{255,0,0},curveStyle,scatterShape)
            simExtCustomUI_addCurve(plotUi,1,sim_customui_curve_type_time,'axis2',{0,255,0},curveStyle,scatterShape)
            simExtCustomUI_addCurve(plotUi,1,sim_customui_curve_type_time,'axis3',{0,128,255},curveStyle,scatterShape)
            simExtCustomUI_addCurve(plotUi,1,sim_customui_curve_type_time,'axis4',{255,255,0},curveStyle,scatterShape)
            simExtCustomUI_setLegendVisibility(plotUi,1,true)
            simExtCustomUI_addCurve(plotUi,2,sim_customui_curve_type_time,'axis1',{255,0,0},curveStyle,scatterShape)
            simExtCustomUI_addCurve(plotUi,2,sim_customui_curve_type_time,'axis2',{0,255,0},curveStyle,scatterShape)
            simExtCustomUI_addCurve(plotUi,2,sim_customui_curve_type_time,'axis3',{0,128,255},curveStyle,scatterShape)
            simExtCustomUI_addCurve(plotUi,2,sim_customui_curve_type_time,'axis4',{255,255,0},curveStyle,scatterShape)
            simExtCustomUI_setLegendVisibility(plotUi,2,true)
            simExtCustomUI_addCurve(plotUi,3,sim_customui_curve_type_time,'axis1',{255,0,0},curveStyle,scatterShape)
            simExtCustomUI_addCurve(plotUi,3,sim_customui_curve_type_time,'axis2',{0,255,0},curveStyle,scatterShape)
            simExtCustomUI_addCurve(plotUi,3,sim_customui_curve_type_time,'axis3',{0,128,255},curveStyle,scatterShape)
            simExtCustomUI_addCurve(plotUi,3,sim_customui_curve_type_time,'axis4',{255,255,0},curveStyle,scatterShape)
            simExtCustomUI_setLegendVisibility(plotUi,3,true)
            simExtCustomUI_addCurve(plotUi,4,sim_customui_curve_type_time,'X',{255,0,0},curveStyle,scatterShape)
            simExtCustomUI_addCurve(plotUi,4,sim_customui_curve_type_time,'Y',{0,255,0},curveStyle,scatterShape)
            simExtCustomUI_addCurve(plotUi,4,sim_customui_curve_type_time,'Z',{0,128,255},curveStyle,scatterShape)
            simExtCustomUI_addCurve(plotUi,4,sim_customui_curve_type_time,'Rot',{255,255,0},curveStyle,scatterShape)
            simExtCustomUI_setLegendVisibility(plotUi,4,true)
        end
        memorizedMotorAngles={}
        memorizedMotorAngles[1]=simGetJointPosition(fkDrivingJoints[1])
        memorizedMotorAngles[2]=simGetJointPosition(fkDrivingJoints[2])
        memorizedMotorAngles[3]=simGetJointPosition(fkDrivingJoints[3])
        memorizedMotorAngles[4]=simGetJointPosition(fkDrivingJoints[4])
        setFkMode()

        blabla=0
        enableMouseInteractionsOnPlot(false)
        local data={}
        data.id=model
        data.ip=c.connectionIp
        data.port=c.connectionPort
        data.timeout=c.connectionTimeout
        data.bufferSize=c.connectionBufferSize
        simExtBwf_query('ragnar_connectReal',data)
    end
end

function disconnect()
    if bwfPluginLoaded then
        if memorizedMotorAngles then
            moveToJointPositions(memorizedMotorAngles)
        end

        local data={}
        data.id=model
        simExtBwf_query('ragnar_disconnectReal',data)
        if plotUi then
            simExtCustomUI_setTitle(plotUi,simGetObjectName(model),true)
        end
        if utils.fastIdleLoop then
            utils.fastIdleLoop(false)
        else
            simSetInt32Parameter(sim_intparam_idle_fps,8)
        end
        connected=false
        paused=false
        updateEnabledDisabledItems()
    end
    enableMouseInteractionsOnPlot(true)
end

function showGraphClick_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=simBoolOr32(c['bitCoded'],8192)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-8192
        closePlot()
    end
    modified=true
    writeInfo(c)
end

function reflectConfigClick_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=simBoolOr32(c['bitCoded'],16384)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-16384
    end
    modified=true
    writeInfo(c)
end

function updatePlotAndRagnarFromRealRagnarIfNeeded()
    if connected and not paused then
        local c=readInfo()
        local data={}
        data.id=model
        data.stateCount=c.connectionBufferSize
        local result,retData=simExtBwf_query('ragnar_getRealStates',data)
        if plotUi then
            if result=='ok' then
                for i=1,4,1 do
                    local label='axis'..i
                    simExtCustomUI_clearCurve(plotUi,1,label)
                    if #retData.timeStamps>0 then
                        local t={}
                        local x={}
                        for j=1,1000,1 do
                            t[j]=blabla+0.01*j
                            x[j]=math.sin(t[j]*(1+0.1*i))
                        end
                        simExtCustomUI_addCurveTimePoints(plotUi,1,label,retData.timeStamps,retData.motorAngles[i])
                    end
                end
                simExtCustomUI_rescaleAxesAll(plotUi,1,false,false)
                simExtCustomUI_replot(plotUi,1)
            end
            --[[
            else
                -- To fake a signal
                if not blabla then
                    blabla=0
                end
                blabla=blabla+0.01
                for i=1,4,1 do
                    local label='axis'..i
                    simExtCustomUI_clearCurve(plotUi,1,label)
                    local t={}
                    local x={}
                    for j=1,1000,1 do
                        t[j]=blabla+0.01*j
                        x[j]=math.sin(t[j]*(1+0.1*i))
                    end
                    simExtCustomUI_addCurveTimePoints(plotUi,1,label,t,x)
                end
                simExtCustomUI_rescaleAxesAll(plotUi,1,false,false)
                simExtCustomUI_replot(plotUi,1)
            end
            --]]
        end
        if simBoolAnd32(c['bitCoded'],16384)>0 then
            local desired={0,0,0,0}
            if result=='ok' then
                if #retData.timeStamps>0 then
                    desired[1]=retData.motorAngles[1][#retData.motorAngles[1]]*math.pi/180
                    desired[2]=retData.motorAngles[2][#retData.motorAngles[2]]*math.pi/180
                    desired[3]=retData.motorAngles[3][#retData.motorAngles[3]]*math.pi/180
                    desired[4]=retData.motorAngles[4][#retData.motorAngles[4]]*math.pi/180
                end
            end
            moveToJointPositions(desired)
        end
    end
end

function moveToJointPositions(desired)
    -- avoid too large steps, otherwise FK/IK doesn't work well
    local dx={}
    local current={}
    local md=0
    for i=1,4,1 do
        current[i]=simGetJointPosition(fkDrivingJoints[i])
        dx[i]=desired[i]-current[i]
        if math.abs(dx[i])>md then
            md=math.abs(dx[i])
        end
    end
    local steps=math.ceil(0.01+md/(5*math.pi/180))
    for i=1,steps,1 do
        for j=1,4,1 do
            simSetJointPosition(fkDrivingJoints[j],current[j]+i*dx[j]/steps)
        end
        simHandleIkGroup(ikGroup)
    end
end

function algorithmClick_callback()
    local s="800 600"
    local p="100 100"
    if algoDlgSize then
        s=algoDlgSize[1]..' '..algoDlgSize[2]
    end
    if algoDlgPos then
        p=algoDlgPos[1]..' '..algoDlgPos[2]
    end
    local xml = [[
        <editor title="Pick and Place Algorithm" editable="true" searchable="true"
            tabWidth="4" textColor="50 50 50" backgroundColor="190 190 190"
            selectionColor="128 128 255" size="]]..s..[[" position="]]..p..[["
            useVrepKeywords="true" isLua="true">
            <keywords2 color="255 100 100" >
                <item word="ragnar_getAllTrackedParts" autocomplete="true" calltip="table allTrackedParts=ragnar_getAllTrackedParts()" />
                <item word="ragnar_getDropLocationInfo" autocomplete="true" calltip="table locationInfo=ragnar_getDropLocationInfo(string destinationName)" />
                <item word="ragnar_moveToPickLocation" autocomplete="true" calltip="ragnar_moveToPickLocation(map part,bool attachPart,number stackingShift)" />
                <item word="ragnar_attachPart" autocomplete="true" calltip="ragnar_attachPart(map part)" />
                <item word="ragnar_detachPart" autocomplete="true" calltip="ragnar_detachPart()" />
                <item word="ragnar_stopTrackingPart" autocomplete="true" calltip="ragnar_stopTrackingPart(map part)" />
                <item word="ragnar_moveToDropLocation" autocomplete="true" calltip="ragnar_moveToDropLocation(map locationInfo,bool detachPart)" />
                <item word="ragnar_getAttachToTarget" autocomplete="true" calltip="bool attach=ragnar_getAttachToTarget()" />
                <item word="ragnar_getPickWithoutTarget" autocomplete="true" calltip="bool pickWithoutTarget=ragnar_getPickWithoutTarget()" />
                <item word="ragnar_getStacking" autocomplete="true" calltip="number stacking=ragnar_getStacking()" />
                
                <item word="ragnar_startPickTime" autocomplete="true" calltip="ragnar_startPickTime(bool isAuxiliaryWindow)" />
                <item word="ragnar_endPickTime" autocomplete="true" calltip="ragnar_endPickTime()" />
                <item word="ragnar_startPlaceTime" autocomplete="true" calltip="ragnar_startPlaceTime()" />
                <item word="ragnar_endPlaceTime" autocomplete="true" calltip="ragnar_endPlaceTime(bool isOtherLocation)" />
                <item word="ragnar_startCycleTime" autocomplete="true" calltip="ragnar_startCycleTime()" />
                <item word="ragnar_endCycleTime" autocomplete="true" calltip="ragnar_endCycleTime(bool didSomething)" />
                <item word="updateMotionParameters" autocomplete="true" calltip="updateMotionParameters()" />

                <item word="ragnar_getTrackingLocationInfo" autocomplete="true" calltip="ragnar_getTrackingLocationInfo(map locationInfo,number processingStage)" />
                <item word="ragnar_moveToTrackingLocation" autocomplete="true" calltip="ragnar_moveToTrackingLocation(map trackingLocationInfo,bool detachPart,bool attachPartToLocation)" />
                <item word="ragnar_incrementTrackedLocationProcessingStage" autocomplete="true" calltip="ragnar_incrementTrackedLocationProcessingStage(map trackingLocationInfo)" />
            </keywords2>

        </editor>
    ]]

    local c=readInfo()
    local initialText=c['algorithm']
    local modifiedText
    modifiedText,algoDlgSize,algoDlgPos=simOpenTextEditor(initialText,xml)
    c['algorithm']=modifiedText
    writeInfo(c)
    modified=true
end

function updateEnabledDisabledItems()
    if ui then
        local simStopped=simGetSimulationState()==sim_simulation_stopped
        simExtCustomUI_setEnabled(ui,2,simStopped,true)
        simExtCustomUI_setEnabled(ui,92,simStopped,true)
        simExtCustomUI_setEnabled(ui,300,simStopped,true)
        simExtCustomUI_setEnabled(ui,301,simStopped,true)
        simExtCustomUI_setEnabled(ui,302,simStopped,true)
        simExtCustomUI_setEnabled(ui,303,simStopped,true)
  --      simExtCustomUI_setEnabled(ui,304,simStopped,true)
        simExtCustomUI_setEnabled(ui,306,simStopped,true)
        simExtCustomUI_setEnabled(ui,3,simStopped,true)
        simExtCustomUI_setEnabled(ui,305,simStopped,true)
        simExtCustomUI_setEnabled(ui,20,simStopped,true)
        simExtCustomUI_setEnabled(ui,39,simStopped,true)
        simExtCustomUI_setEnabled(ui,21,simStopped,true)
        simExtCustomUI_setEnabled(ui,77,simStopped,true)
        simExtCustomUI_setEnabled(ui,501,simStopped,true)
        simExtCustomUI_setEnabled(ui,502,simStopped,true)
        simExtCustomUI_setEnabled(ui,503,simStopped,true)
        simExtCustomUI_setEnabled(ui,504,simStopped,true)
        simExtCustomUI_setEnabled(ui,2001,simStopped,true)

        local connectionAllowed=bwfPluginLoaded and simStopped
        simExtCustomUI_setEnabled(ui,1200,connectionAllowed and not connected,true)
        simExtCustomUI_setEnabled(ui,1201,connectionAllowed and not connected,true)
        simExtCustomUI_setEnabled(ui,1202,connectionAllowed and not connected,true)
        simExtCustomUI_setEnabled(ui,1203,connectionAllowed and not connected,true)
        simExtCustomUI_setEnabled(ui,1204,connectionAllowed and not connected,true)
        simExtCustomUI_setEnabled(ui,1208,connectionAllowed and not connected,true)
        simExtCustomUI_setEnabled(ui,1209,connectionAllowed and not connected,true)
        simExtCustomUI_setEnabled(ui,1205,connectionAllowed and connected and not paused,true)
        simExtCustomUI_setEnabled(ui,1206,connectionAllowed and connected and paused,true)
        simExtCustomUI_setEnabled(ui,1207,connectionAllowed and connected,true)

    end
end

function partTrackingWindowChange_callback(ui,id,newIndex)
    local newLoc=comboPartTrackingWindow[newIndex+1][2]
    bwUtils.setReferencedObjectHandle(model,REF_PART_TRACKING1,newLoc)
    if bwUtils.getReferencedObjectHandle(model,REF_PART_TRACKING2)==newLoc then
        bwUtils.setReferencedObjectHandle(model,REF_PART_TRACKING2,-1)
    end
    if bwUtils.getReferencedObjectHandle(model,REF_TARGET_TRACKING1)==newLoc then
        bwUtils.setReferencedObjectHandle(model,REF_TARGET_TRACKING1,-1)
    end
    modified=true
    updateTrackingWindowComboboxes()
end

function auxPartTrackingWindowChange_callback(ui,id,newIndex)
    local newLoc=comboAuxPartTrackingWindow[newIndex+1][2]
    bwUtils.setReferencedObjectHandle(model,REF_PART_TRACKING2,newLoc)
    if bwUtils.getReferencedObjectHandle(model,REF_PART_TRACKING1)==newLoc then
        bwUtils.setReferencedObjectHandle(model,REF_PART_TRACKING1,-1)
    end
    if bwUtils.getReferencedObjectHandle(model,REF_TARGET_TRACKING1)==newLoc then
        bwUtils.setReferencedObjectHandle(model,REF_TARGET_TRACKING1,-1)
    end
    modified=true
    updateTrackingWindowComboboxes()
end

function locationTrackingWindowChange_callback(ui,id,newIndex)
    local newLoc=comboLocationTrackingWindow[newIndex+1][2]
    bwUtils.setReferencedObjectHandle(model,REF_TARGET_TRACKING1,newLoc)
    if bwUtils.getReferencedObjectHandle(model,REF_PART_TRACKING1)==newLoc then
        bwUtils.setReferencedObjectHandle(model,REF_PART_TRACKING1,-1)
    end
    if bwUtils.getReferencedObjectHandle(model,REF_PART_TRACKING2)==newLoc then
        bwUtils.setReferencedObjectHandle(model,REF_PART_TRACKING2,-1)
    end
    modified=true
    updateTrackingWindowComboboxes()
end


function updateDropLocationComboboxes()
    local loc=getAvailableDropLocations(false)
    comboDropLocations={}
    local exceptItems={}
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION2))]=true
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION3))]=true
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION4))]=true
--    exceptItems['<NONE>']=nil
    comboDropLocations[1]=customUi_populateCombobox(ui,501,loc,exceptItems,bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION1)),true,{{'<NONE>',-1}})

    exceptItems={}
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION1))]=true
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION3))]=true
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION4))]=true
--    exceptItems['<NONE>']=nil
    comboDropLocations[2]=customUi_populateCombobox(ui,502,loc,exceptItems,bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION2)),true,{{'<NONE>',-1}})

    exceptItems={}
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION1))]=true
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION2))]=true
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION4))]=true
--    exceptItems['<NONE>']=nil
    comboDropLocations[3]=customUi_populateCombobox(ui,503,loc,exceptItems,bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION3)),true,{{'<NONE>',-1}})

    exceptItems={}
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION1))]=true
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION2))]=true
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION3))]=true
--    exceptItems['<NONE>']=nil
    comboDropLocations[4]=customUi_populateCombobox(ui,504,loc,exceptItems,bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION4)),true,{{'<NONE>',-1}})
end

function dropLocationChange_callback(ui,id,newIndex)
    local newLoc=comboDropLocations[id-500][newIndex+1][2]
    bwUtils.setReferencedObjectHandle(model,REF_DROP_LOCATION1+id-500-1,newLoc)
    for i=1,4,1 do
        if i~=id-500 then
            if bwUtils.getReferencedObjectHandle(model,REF_DROP_LOCATION1+i-1)==newLoc then
                bwUtils.setReferencedObjectHandle(model,REF_DROP_LOCATION1+i-1,-1)
            end
        end
    end
    modified=true
    updateDropLocationComboboxes()
end

function updateTrackingWindowComboboxes()
    local loc=getAvailableTrackingWindows()
    local exceptItems={}
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_PART_TRACKING2))]=true
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_TARGET_TRACKING1))]=true
--    exceptItems['<NONE>']=nil
    comboPartTrackingWindow=customUi_populateCombobox(ui,20,loc,exceptItems,bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_PART_TRACKING1)),true,{{'<NONE>',-1}})

    exceptItems={}
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_PART_TRACKING1))]=true
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_TARGET_TRACKING1))]=true
--    exceptItems['<NONE>']=nil
    comboAuxPartTrackingWindow=customUi_populateCombobox(ui,39,loc,exceptItems,bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_PART_TRACKING2)),true,{{'<NONE>',-1}})

    exceptItems={}
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_PART_TRACKING1))]=true
--    exceptItems[bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_PART_TRACKING2))]=true
--    exceptItems['<NONE>']=nil
    comboLocationTrackingWindow=customUi_populateCombobox(ui,21,loc,exceptItems,bwUtils.getObjectNameOrNone(bwUtils.getReferencedObjectHandle(model,REF_TARGET_TRACKING1)),true,{{'<NONE>',-1}})
end

function createDlg()
    if (not ui) and bwUtils.canOpenPropertyDialog() then
        local xml =[[
    <tabs id="78">
    <tab title="General" layout="form">
                <label text="Enabled"/>
                <checkbox text="" onchange="enabledClicked_callback" id="1000"/>

                <label text="Maximum speed (mm/s)"/>
                <edit oneditingfinished="velocityChange_callback" id="10"/>

                <label text="Maximum acceleration (mm/s^2)"/>
                <edit oneditingfinished="accelerationChange_callback" id="11"/>

                <label text="Dwell time (s)"/>
                <edit oneditingfinished="dwellTimeChange_callback" id="12"/>

                <label text="Tracking time shift (s)"/>
                <edit oneditingfinished="trackingTimeShiftChange_callback" id="13"/>
    </tab>
    <tab title="Pick/Place">
            <group layout="form" flat="true">
                <label text="Pick approach height (mm)"/>
                <edit oneditingfinished="pickApproachHeightChange_callback" id="1007"/>

                <label text="Pick offset (X, Y, Z, in mm)"/>
                <edit oneditingfinished="pickOffsetChange_callback" id="1001"/>

                <label text="Pick rounding (mm)"/>
                <edit oneditingfinished="pickRoundingChange_callback" id="1003"/>

                <label text="Pick nulling accuracy (mm)"/>
                <edit oneditingfinished="pickNullingChange_callback" id="1005"/>
            </group>
            <group layout="form" flat="true">
                <label text="Place approach height (mm)"/>
                <edit oneditingfinished="placeApproachHeightChange_callback" id="1008"/>

                <label text="Place offset (X, Y, Z, in mm)"/>
                <edit oneditingfinished="placeOffsetChange_callback" id="1002"/>

                <label text="Place rounding (mm)"/>
                <edit oneditingfinished="placeRoundingChange_callback" id="1004"/>

                <label text="Place nulling accuracy (mm)"/>
                <edit oneditingfinished="placeNullingChange_callback" id="1006"/>
            </group>


            <group layout="form" flat="true">
                <label text="Pick and place algorithm"/>
                <button text="Edit" checked="false"  onclick="algorithmClick_callback" id="403" />

                <label text="Pick also without target in sight"/>
                <checkbox text="" onchange="pickWithoutTargetClicked_callback" id="2001"/>

                <label text="Attach part to target"/>
                <checkbox text="" onchange="attachPartClicked_callback" id="2000"/>
            </group>
    </tab>
    <tab title="Configuration" layout="form">
                <label text="Primary part tracking window"/>
                <combobox id="20" onchange="partTrackingWindowChange_callback">
                </combobox>

                <label text="Auxiliary part tracking window"/>
                <combobox id="39" onchange="auxPartTrackingWindowChange_callback">
                </combobox>

                <label text=""/>
                <label text=""/>

                <label text="Target tracking window"/>
                <combobox id="21" onchange="locationTrackingWindowChange_callback">
                </combobox>

                <label text="Drop location 1"/>
                <combobox id="501" onchange="dropLocationChange_callback">
                </combobox>

                <label text="Drop location 2"/>
                <combobox id="502" onchange="dropLocationChange_callback">
                </combobox>

                <label text="Drop location 3"/>
                <combobox id="503" onchange="dropLocationChange_callback">
                </combobox>

                <label text="Drop location 4"/>
                <combobox id="504" onchange="dropLocationChange_callback">
                </combobox>
                
    </tab>
    <tab title="Robot">
            <group layout="form" flat="true">
                <label text="Primary arm length" id="1"/>
                <hslider tick-position="above" tick-interval="1" minimum="0" maximum="7" onchange="sizeAChange_callback" id="2"/>

                <label text="Secondary arm length" id="91"/>
                <hslider tick-position="above" tick-interval="1" minimum="0" maximum="17" onchange="sizeBChange_callback" id="92"/>

                <label text="Z position (mm)"/>
                <edit oneditingfinished="ZChange_callback" id="77"/>

                <label text="Frame is visible"/>
                <checkbox text="" checked="false" onchange="visibleFrameClick_callback" id="302"/>

                <label text="Frame is open"/>
                <checkbox text="" checked="false" onchange="openFrameClick_callback" id="301"/>

                <label text="Frame low beams are visible"/>
                <checkbox text="" checked="false" onchange="visibleFrameLowBeamsClick_callback" id="303"/>
            </group>
            <label text="" style="* {margin-left: 350px;}"/>
    </tab>
    <tab title="More" layout="form">
                <label text="Visualize workspace"/>
                <checkbox text="" checked="false" onchange="visualizeWorkspaceClick_callback" id="3"/>

                <label text="Visualize workspace also during simulation"/>
                <checkbox text="" checked="false" onchange="visualizeWorkspaceSimClick_callback" id="305"/>

                <label text="Visualize trajectory"/>
                <checkbox text="" checked="false" onchange="visualizeTrajectoryClick_callback" id="300"/>

                <label text="Show statistics"/>
                <checkbox text="" checked="false" onchange="showStatisticsClick_callback" id="304"/>

                <label text="Ragnar is slave (special)"/>
                <checkbox text="" checked="false" onchange="ragnarIsIdle_callback" id="306"/>
    </tab>
    <tab title="Online" layout="grid">
        <group flat="true" layout="form">
                <label text="IP address"/>
                <edit oneditingfinished="ip_callback" id="1200"/>

                <label text="Port"/>
                <edit oneditingfinished="port_callback" id="1201"/>

                <label text="Timeout (s)"/>
                <edit oneditingfinished="timeout_callback" id="1202"/>

                <label text="Buffer size (states)"/>
                <edit oneditingfinished="bufferSize_callback" id="1203"/>

                <label text="Show graph upon connection"/>
                <checkbox text="" checked="false" onchange="showGraphClick_callback" id="1208"/>

                <label text="Reflect Ragnar configuration upon connection"/>
                <checkbox text="" checked="false" onchange="reflectConfigClick_callback" id="1209"/>
        </group>
        <br/>
        <group flat="true">
                <button text="Connect" onclick="connect_callback" id="1204" />
                <button text="Pause" onclick="pause_callback" id="1205" />
                <button text="Resume" onclick="resume_callback" id="1206" />
                <button text="Disconnect" onclick="disconnect_callback" id="1207" />
        </group>
    </tab>
    </tabs>
        ]]

        ui=bwUtils.createCustomUi(xml,simGetObjectName(model),previousDlgPos--[[,closeable,onCloseFunction,modal,resizable,activate,additionalUiAttribute--]])
        local c=readInfo()
        simExtCustomUI_setSliderValue(ui,2,(c['primaryArmLengthInMM']-200)/50,true)
        simExtCustomUI_setSliderValue(ui,92,(c['secondaryArmLengthInMM']-400)/50,true)
        simExtCustomUI_setCheckboxValue(ui,3,bwUtils.getCheckboxValFromBool(simBoolAnd32(c['bitCoded'],256)~=0),true)
        simExtCustomUI_setCheckboxValue(ui,305,bwUtils.getCheckboxValFromBool(simBoolAnd32(c['bitCoded'],512)~=0),true)
        simExtCustomUI_setCheckboxValue(ui,300,bwUtils.getCheckboxValFromBool(simBoolAnd32(c['bitCoded'],1)~=0),true)
        simExtCustomUI_setCheckboxValue(ui,301,bwUtils.getCheckboxValFromBool(simBoolAnd32(c['bitCoded'],2)~=0),true)
        simExtCustomUI_setCheckboxValue(ui,302,bwUtils.getCheckboxValFromBool(simBoolAnd32(c['bitCoded'],4)~=0),true)
        simExtCustomUI_setCheckboxValue(ui,303,bwUtils.getCheckboxValFromBool(simBoolAnd32(c['bitCoded'],8)~=0),true)
        simExtCustomUI_setCheckboxValue(ui,1000,bwUtils.getCheckboxValFromBool(simBoolAnd32(c['bitCoded'],64)~=0),true)
        simExtCustomUI_setCheckboxValue(ui,304,bwUtils.getCheckboxValFromBool(simBoolAnd32(c['bitCoded'],128)~=0),true)
        simExtCustomUI_setCheckboxValue(ui,306,bwUtils.getCheckboxValFromBool(simBoolAnd32(c['bitCoded'],4096)~=0),true)
        simExtCustomUI_setCheckboxValue(ui,2000,bwUtils.getCheckboxValFromBool(simBoolAnd32(c['bitCoded'],1024)~=0),true)
        simExtCustomUI_setCheckboxValue(ui,2001,bwUtils.getCheckboxValFromBool(simBoolAnd32(c['bitCoded'],2048)~=0),true)
        simExtCustomUI_setEditValue(ui,77,string.format("%.0f",getZPosition()*1000),true)

        simExtCustomUI_setEditValue(ui,1200,c['connectionIp'],true)
        simExtCustomUI_setEditValue(ui,1201,string.format("%i",c['connectionPort']),true)
        simExtCustomUI_setEditValue(ui,1202,string.format("%.2f",c['connectionTimeout']),true)
        simExtCustomUI_setEditValue(ui,1203,string.format("%i",c['connectionBufferSize']),true)
        simExtCustomUI_setCheckboxValue(ui,1208,bwUtils.getCheckboxValFromBool(simBoolAnd32(c['bitCoded'],8192)~=0),true)
        simExtCustomUI_setCheckboxValue(ui,1209,bwUtils.getCheckboxValFromBool(simBoolAnd32(c['bitCoded'],16384)~=0),true)

        updateTrackingWindowComboboxes()
        updateDropLocationComboboxes()
        updateLinkLengthDisplay()
        updateMovementParamDisplay()
        updateEnabledDisabledItems()
        simExtCustomUI_setCurrentTab(ui,78,dlgMainTabIndex,true)
    end
end

function showDlg()
    if not ui then
        createDlg()
    end
end

function removeDlg()
    if ui then
        if version>30301 or ( version==30301 and revision>=4 ) then
            local x,y=simExtCustomUI_getPosition(ui)
            previousDlgPos={x,y}
            dlgMainTabIndex=simExtCustomUI_getCurrentTab(ui,78)
        end
        simExtCustomUI_destroy(ui)
        ui=nil
    end
end

if (sim_call_type==sim_customizationscriptcall_initialization) then
    REF_PART_TRACKING1=1 -- primary part tracking window
    REF_PART_TRACKING2=2 -- aux part tracking window
    -- Free spots here
    REF_TARGET_TRACKING1=11 -- target tracking window
    -- Free spots here
    REF_DROP_LOCATION1=21 -- drop location 1
    REF_DROP_LOCATION2=22 -- drop location 2
    REF_DROP_LOCATION3=23 -- drop location 3
    REF_DROP_LOCATION4=24 -- drop location 4
    version=simGetInt32Parameter(sim_intparam_program_version)
    revision=simGetInt32Parameter(sim_intparam_program_revision)

    model=simGetObjectAssociatedWithScript(sim_handle_self)
    _MODELVERSION_=0
    _CODEVERSION_=0
    local _info=readInfo()
    bwUtils.checkIfCodeAndModelMatch(model,_CODEVERSION_,_info['version'])
    bwfPluginLoaded=utils.isPluginLoaded('Bwf')
    -- Following for backward compatibility:
    if _info['partTrackingWindow'] then
        bwUtils.setReferencedObjectHandle(model,REF_PART_TRACKING1,getObjectHandle_noErrorNoSuffixAdjustment(_info['partTrackingWindow']))
        _info['partTrackingWindow']=nil
    end
    if _info['auxPartTrackingWindow'] then
        bwUtils.setReferencedObjectHandle(model,REF_PART_TRACKING2,getObjectHandle_noErrorNoSuffixAdjustment(_info['auxPartTrackingWindow']))
        _info['auxPartTrackingWindow']=nil
    end
    if _info['targetTrackingWindow'] then
        bwUtils.setReferencedObjectHandle(model,REF_TARGET_TRACKING1,getObjectHandle_noErrorNoSuffixAdjustment(_info['targetTrackingWindow']))
        _info['targetTrackingWindow']=nil
    end
    if _info['dropLocations'] then
        while #_info['dropLocations']>4 do
            table.remove(_info['dropLocations'])
        end
        while #_info['dropLocations']<4 do
            table.insert(_info['dropLocations'],'<NONE>')
        end
        bwUtils.setReferencedObjectHandle(model,REF_DROP_LOCATION1,getObjectHandle_noErrorNoSuffixAdjustment(_info['dropLocations'][1]))
        bwUtils.setReferencedObjectHandle(model,REF_DROP_LOCATION2,getObjectHandle_noErrorNoSuffixAdjustment(_info['dropLocations'][2]))
        bwUtils.setReferencedObjectHandle(model,REF_DROP_LOCATION3,getObjectHandle_noErrorNoSuffixAdjustment(_info['dropLocations'][3]))
        bwUtils.setReferencedObjectHandle(model,REF_DROP_LOCATION4,getObjectHandle_noErrorNoSuffixAdjustment(_info['dropLocations'][4]))
        _info['dropLocations']=nil
    end
    if _info['sizeA'] then
        local p1=200+math.floor(0.5+(_info['sizeA']-0.2005)/0.05)*50
        local p2=50*math.ceil((_info['sizeA']*_info['paramF']-0.001)/0.05)
        _info['primaryArmLengthInMM']=p1
        _info['secondaryArmLengthInMM']=p2
        _info['sizeA']=nil
        _info['paramF']=nil
    end
    ----------------------------------------
    writeInfo(_info)
    connected=false
    paused=false

    ikGroup=simGetIkGroupHandle('Ragnar')
    ikTarget=simGetObjectHandle('Ragnar_InvKinTarget')
    ikModeTipDummy=simGetObjectHandle('Ragnar_InvKinTip')
    fkDrivingJoints={-1,-1,-1,-1}
    fkDrivingJoints[1]=simGetObjectHandle('Ragnar_A1DrivingJoint1')
    fkDrivingJoints[2]=simGetObjectHandle('Ragnar_A1DrivingJoint2')
    fkDrivingJoints[3]=simGetObjectHandle('Ragnar_A1DrivingJoint3')
    fkDrivingJoints[4]=simGetObjectHandle('Ragnar_A1DrivingJoint4')


    modified=false
    lastT=simGetSystemTimeInMs(-1)
    dlgMainTabIndex=0

    upperLinks={}
    lowerLinks={}

    upperArmAdjust={}
    lowerArmAdjust={}

    upperArmLAdjust={}
    lowerArmLAdjust={}

    frontAndRearCoverAdjust={simGetObjectHandle('Ragnar_frontAdjust'),simGetObjectHandle('Ragnar_rearAdjust')}
    middleCoverParts={}

    drivingJoints={}

    for i=1,4,1 do
        drivingJoints[#upperLinks+1]=simGetObjectHandle('Ragnar_A1DrivingJoint'..i)

        upperLinks[#upperLinks+1]=simGetObjectHandle('Ragnar_upperArmLink'..i-1)
        lowerLinks[#lowerLinks+1]=simGetObjectHandle('Ragnar_lowerArmLinkA'..i-1)
        lowerLinks[#lowerLinks+1]=simGetObjectHandle('Ragnar_lowerArmLinkB'..i-1)

        upperArmAdjust[#upperArmAdjust+1]=simGetObjectHandle('Ragnar_upperArmAdjust'..i-1)
        lowerArmAdjust[#lowerArmAdjust+1]=simGetObjectHandle('Ragnar_lowerArmAdjustA'..i-1)
        lowerArmAdjust[#lowerArmAdjust+1]=simGetObjectHandle('Ragnar_lowerArmAdjustB'..i-1)

        upperArmLAdjust[#upperArmLAdjust+1]=simGetObjectHandle('Ragnar_upperArmLAdjust'..i-1)
        lowerArmLAdjust[#lowerArmLAdjust+1]=simGetObjectHandle('Ragnar_lowerArmLAdjustA'..i-1)
        lowerArmLAdjust[#lowerArmLAdjust+1]=simGetObjectHandle('Ragnar_lowerArmLAdjustB'..i-1)
    end

    for i=1,5,1 do
        middleCoverParts[i]=simGetObjectHandle('Ragnar_middleCover'..i)
    end

    frameModel=simGetObjectHandle('Ragnar_frame')
    frameBeams={}
    for i=1,8,1 do
        frameBeams[i]=simGetObjectHandle('Ragnar_frame_beam'..i)
    end
    frameJoints={}
    frameJoints[1]=simGetObjectHandle('Ragnar_frame_widthJ1')
    frameJoints[2]=simGetObjectHandle('Ragnar_frame_widthJ2')
    frameJoints[3]=simGetObjectHandle('Ragnar_frame_heightJ1')
    frameJoints[4]=simGetObjectHandle('Ragnar_frame_heightJ2')
    frameJoints[5]=simGetObjectHandle('Ragnar_frame_heightJ3')
    frameJoints[6]=simGetObjectHandle('Ragnar_frame_heightJ4')
    frameJoints[7]=simGetObjectHandle('Ragnar_frame_lengthJ1')
    frameJoints[8]=simGetObjectHandle('Ragnar_frame_lengthJ2')
    frameJoints[9]=simGetObjectHandle('Ragnar_frame_lengthJ3')
    frameJoints[10]=simGetObjectHandle('Ragnar_frame_lengthJ4')

    frameOpenClose={}
    for i=1,3,1 do
        frameOpenClose[i]=simGetObjectHandle('Ragnar_frame_openCloseJ'..i)
    end

    workspace=simGetObjectHandle('Ragnar_workspace')

	simSetScriptAttribute(sim_handle_self,sim_customizationscriptattribute_activeduringsimulation,true)
    updatePluginRepresentation()
    previousDlgPos,algoDlgSize,algoDlgPos,distributionDlgSize,distributionDlgPos,previousDlg1Pos=bwUtils.readSessionPersistentObjectData(model,"dlgPosAndSize")
end

showOrHideUiIfNeeded=function()
    local s=simGetObjectSelection()
    if s and #s>=1 and s[#s]==model then
        showDlg()
    else
        removeDlg()
    end
end

if (sim_call_type==sim_customizationscriptcall_nonsimulation) then
    showOrHideUiIfNeeded()
    if simGetSystemTimeInMs(lastT)>3000 then
        lastT=simGetSystemTimeInMs(-1)
        if modified then
            simAnnounceSceneContentChange() -- to have an undo point
            modified=false
        end
    end
    updatePlotAndRagnarFromRealRagnarIfNeeded()
end

if (sim_call_type==sim_customizationscriptcall_simulationsensing) then
    if simJustStarted then
        updateEnabledDisabledItems()
    end
    simJustStarted=nil
    showOrHideUiIfNeeded()
end

if (sim_call_type==sim_customizationscriptcall_simulationpause) then
    showOrHideUiIfNeeded()
end

if (sim_call_type==sim_customizationscriptcall_firstaftersimulation) then
    updateEnabledDisabledItems()
    local c=readInfo()
    if simBoolAnd32(c['bitCoded'],256)==256 then
        simSetObjectInt32Parameter(workspace,sim_objintparam_visibility_layer,1)
    else
        simSetObjectInt32Parameter(workspace,sim_objintparam_visibility_layer,0)
    end
end

if (sim_call_type==sim_customizationscriptcall_lastbeforesimulation) then
    disconnect()
    closePlot()
    simJustStarted=true
    local c=readInfo()
    local showWs=bwUtils.modifyAuxVisualizationItems(simBoolAnd32(c['bitCoded'],256+512)==256+512)
    if showWs then
        simSetObjectInt32Parameter(workspace,sim_objintparam_visibility_layer,1)
    else
        simSetObjectInt32Parameter(workspace,sim_objintparam_visibility_layer,0)
    end
end

if (sim_call_type==sim_customizationscriptcall_lastbeforeinstanceswitch) then
    disconnect()
    closePlot()
    removeDlg()
    removeFromPluginRepresentation()
end

if (sim_call_type==sim_customizationscriptcall_firstafterinstanceswitch) then
    updatePluginRepresentation()
end

if (sim_call_type==sim_customizationscriptcall_cleanup) then
    disconnect()
    closePlot()
    removeDlg()
    removeFromPluginRepresentation()
    bwUtils.writeSessionPersistentObjectData(model,"dlgPosAndSize",previousDlgPos,algoDlgSize,algoDlgPos,distributionDlgSize,distributionDlgPos,previousDlg1Pos)
end