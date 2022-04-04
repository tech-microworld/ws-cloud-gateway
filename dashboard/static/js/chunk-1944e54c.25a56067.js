(window["webpackJsonp"]=window["webpackJsonp"]||[]).push([["chunk-1944e54c"],{"4a7e":function(t,e,a){},"7cf7":function(t,e,a){},c23d:function(t,e,a){"use strict";a("7cf7")},d590:function(t,e,a){"use strict";a("4a7e")},dc76:function(t,e,a){"use strict";a.r(e);var o=function(){var t=this,e=t.$createElement,a=t._self._c||e;return a("div",{staticClass:"app-container"},[a("div",{staticClass:"filter-container"},[a("el-button",{staticClass:"filter-item",staticStyle:{"margin-left":"10px"},attrs:{type:"success",icon:"el-icon-plus",size:"small"},on:{click:t.handleCreate}},[t._v("添加")])],1),t._v(" "),a("el-table",{directives:[{name:"loading",rawName:"v-loading",value:t.listLoading,expression:"listLoading"}],attrs:{data:t.list,"element-loading-text":"Loading",border:"",fit:"","highlight-current-row":""}},[a("el-table-column",{attrs:{label:"协议",width:"110",align:"center"},scopedSlots:t._u([{key:"default",fn:function(e){return[t._v(t._s(e.row.protocol))]}}])}),t._v(" "),a("el-table-column",{attrs:{label:"Hosts",align:"center"},scopedSlots:t._u([{key:"default",fn:function(e){return[a("span",[t._v(t._s(t._f("hostFilter")(e.row.hosts)))])]}}])}),t._v(" "),a("el-table-column",{attrs:{label:"路由前缀"},scopedSlots:t._u([{key:"default",fn:function(e){return[t._v(t._s(e.row.prefix))]}}])}),t._v(" "),a("el-table-column",{attrs:{label:"服务名",width:"110",align:"center"},scopedSlots:t._u([{key:"default",fn:function(e){return[a("span",[t._v(t._s(e.row.service_name))])]}}])}),t._v(" "),a("el-table-column",{attrs:{label:"说明",align:"left"},scopedSlots:t._u([{key:"default",fn:function(e){return[a("span",[t._v(t._s(e.row.remark))])]}}])}),t._v(" "),a("el-table-column",{attrs:{"class-name":"status-col",label:"是否启用",width:"110",align:"center"},scopedSlots:t._u([{key:"default",fn:function(e){return[a("el-tag",{attrs:{type:t._f("statusFilter")(e.row.status)}},[t._v(t._s(t._f("dict")(e.row.status,"routeStatus")))])]}}])}),t._v(" "),a("el-table-column",{attrs:{label:"更新时间",align:"left"},scopedSlots:t._u([{key:"default",fn:function(e){return[a("span",[t._v(t._s(t._f("parseTime")(e.row.time)))])]}}])}),t._v(" "),a("el-table-column",{attrs:{label:"操作",align:"center","class-name":"small-padding fixed-width"},scopedSlots:t._u([{key:"default",fn:function(e){var o=e.row;return[a("el-button",{attrs:{type:"primary",size:"mini"},on:{click:function(e){return t.handleUpdate(o)}}},[t._v("修改")]),t._v(" "),a("el-button",{attrs:{type:"danger",size:"mini"},on:{click:function(e){return t.handleDelete(o)}}},[t._v("删除")])]}}])})],1),t._v(" "),a("el-dialog",{attrs:{title:t.textMap[t.dialogStatus],visible:t.dialogFormVisible},on:{"update:visible":function(e){t.dialogFormVisible=e}}},[a("el-form",{ref:"dataForm",staticStyle:{width:"400px margin-left:50px"},attrs:{rules:t.dataFormRules,model:t.dataFormModel,"label-position":"right","label-width":"85px",size:"mini"}},[a("el-form-item",{attrs:{label:"协议",prop:"protocol"}},[a("el-select",{attrs:{placeholder:"选择协议"},model:{value:t.dataFormModel.protocol,callback:function(e){t.$set(t.dataFormModel,"protocol",e)},expression:"dataFormModel.protocol"}},t._l(t.protocolOptions,(function(t){return a("el-option",{key:t.value,attrs:{label:t.label,value:t.value}})})),1)],1),t._v(" "),a("el-form-item",{attrs:{label:"Hosts",prop:"hosts"}},[a("el-input",{attrs:{placeholder:"非必填，多个使用,分隔 eg: example.com,example.cn"},model:{value:t.dataFormModel.hosts,callback:function(e){t.$set(t.dataFormModel,"hosts",e)},expression:"dataFormModel.hosts"}})],1),t._v(" "),a("el-form-item",{attrs:{label:"路由前缀",prop:"prefix"}},[a("el-input",{attrs:{placeholder:"eg: /openapi/user"},model:{value:t.dataFormModel.prefix,callback:function(e){t.$set(t.dataFormModel,"prefix",e)},expression:"dataFormModel.prefix"}})],1),t._v(" "),a("el-form-item",{attrs:{label:"服务名",prop:"service_name"}},[a("el-input",{attrs:{placeholder:"eg: user"},model:{value:t.dataFormModel.service_name,callback:function(e){t.$set(t.dataFormModel,"service_name",e)},expression:"dataFormModel.service_name"}})],1),t._v(" "),a("el-form-item",{attrs:{label:"是否启用",prop:"enable"}},[a("el-switch",{attrs:{"active-value":1,"inactive-value":0},model:{value:t.dataFormModel.status,callback:function(e){t.$set(t.dataFormModel,"status",e)},expression:"dataFormModel.status"}})],1),t._v(" "),a("el-form-item",{attrs:{label:"plugins",prop:"plugins"}},[a("el-select",{attrs:{multiple:"",placeholder:"请选择"},model:{value:t.dataFormModel.plugins,callback:function(e){t.$set(t.dataFormModel,"plugins",e)},expression:"dataFormModel.plugins"}},t._l(t.plugins,(function(t){return a("el-option",{key:t.value,attrs:{label:t.label,value:t.value}})})),1)],1),t._v(" "),a("el-form-item",{attrs:{label:"参数",prop:"propsData"}},[a("div",{staticClass:"editor-container"},[a("json-editor",{ref:"jsonEditor",model:{value:t.dataFormModel.propsData,callback:function(e){t.$set(t.dataFormModel,"propsData",e)},expression:"dataFormModel.propsData"}})],1)]),t._v(" "),a("el-form-item",{attrs:{label:"说明",prop:"remark"}},[a("el-input",{attrs:{autosize:{minRows:2,maxRows:4},type:"textarea",placeholder:"备注、说明"},model:{value:t.dataFormModel.remark,callback:function(e){t.$set(t.dataFormModel,"remark",e)},expression:"dataFormModel.remark"}})],1)],1),t._v(" "),a("div",{staticClass:"dialog-footer",attrs:{slot:"footer"},slot:"footer"},[a("el-button",{on:{click:function(e){t.dialogFormVisible=!1}}},[t._v("取消")]),t._v(" "),a("el-button",{attrs:{type:"primary"},on:{click:function(e){return t.submitDataForm()}}},[t._v("提交")])],1)],1)],1)},r=[],l=(a("28a5"),a("7f7f"),a("ac6a"),function(){var t=this,e=t.$createElement,a=t._self._c||e;return a("div",{staticClass:"json-editor"},[a("textarea",{ref:"textarea"})])}),s=[],i=a("56b3"),n=a.n(i);a("0dd0"),a("a7be"),a("acdf"),a("f9d4"),a("8822"),a("d2de");a("ae67");var u={name:"JsonEditor",props:["value"],data:function(){return{jsonEditor:!1}},watch:{value:function(t){var e=this.jsonEditor.getValue();if(t!==e){var a=this.value;"string"!==typeof this.value&&(a=JSON.stringify(this.value,null,2)),this.jsonEditor.setValue(a)}}},mounted:function(){var t=this;this.jsonEditor=n.a.fromTextArea(this.$refs.textarea,{lineNumbers:!0,mode:"application/json",gutters:["CodeMirror-lint-markers"],theme:"rubyblue",lint:!0});var e=this.value;"string"!==typeof this.value&&(e=JSON.stringify(this.value,null,2)),this.jsonEditor.setValue(e),this.jsonEditor.on("change",(function(e){t.$emit("changed",e.getValue()),t.$emit("input",e.getValue())}))},methods:{getValue:function(){return this.jsonEditor.getValue()}}},d=u,c=(a("c23d"),a("2877")),p=Object(c["a"])(d,l,s,!1,null,"7eb646c0",null),m=p.exports,f=a("61f7"),g=a("b775");function v(t){return Object(g["a"])({url:"/admin/routes/list",method:"get",params:t})}function h(t){return Object(g["a"])({url:"/admin/routes/save",method:"post",data:t})}function b(t){return Object(g["a"])({url:"/admin/routes/remove",method:"post",data:t})}function _(){return Object(g["a"])({url:"/admin/plugins/list",method:"get"})}var F={key:"",protocol:"http",remark:"",hosts:"",prefix:"",service_name:"",status:1,plugins:[],props:{},propsData:"{}"},M={components:{JsonEditor:m},filters:{statusFilter:function(t){var e={1:"success",0:"danger"};return e[t]},hostFilter:function(t){return Array.isArray(t)?t.join(","):""}},data:function(){var t=this,e=function(e,a,o){var r=t.dataFormModel.propsData;r?Object(f["b"])(r)?o():(console.log("not json string: ",r),o(new Error("请检查参数格式，必须是 json object"))):o()};return{list:null,listLoading:!0,dataFormModel:Object.assign({},F),enable:!0,dialogFormVisible:!1,dialogStatus:"",textMap:{update:"修改路由",create:"添加路由"},dialogPvVisible:!1,plugins:[],dataFormRules:{prefix:[{required:!0,message:"请输入路由前缀",trigger:"blur"}],protocol:[{required:!0,message:"请输入路由前缀",trigger:"blur"}],service_name:[{required:!0,message:"请输入服务名",trigger:"blur"}],propsData:[{validator:e,trigger:"blur"}]},protocolOptions:[{value:"http",label:"http"},{value:"grpc",label:"grpc"}]}},created:function(){this.getList(),this.getPlugins()},methods:{getPlugins:function(){var t=this;_().then((function(e){var a=[];e.data&&e.data.length>0&&e.data.forEach((function(t){a.push({value:t.name,label:t.desc})})),t.plugins=a}))},getList:function(){var t=this;this.listLoading=!0,v().then((function(e){t.list=e.data,t.listLoading=!1}))},resetFormModel:function(){this.dataFormModel=Object.assign({},F)},handleCreate:function(){var t=this;this.resetFormModel(),this.dialogStatus="create",this.dialogFormVisible=!0,this.$nextTick((function(){t.$refs.dataForm.clearValidate()}))},handleUpdate:function(t){var e=this;this.dataFormModel=Object.assign({},t),console.info("dataFormModel ",this.dataFormModel),this.dataFormModel.propsData=JSON.stringify(t.props,null,2),this.dataFormModel.hosts=Array.isArray(t.hosts)?t.hosts.join(","):"",this.dialogStatus="update",this.dialogFormVisible=!0,this.$nextTick((function(){e.$refs.dataForm.clearValidate()}))},submitDataForm:function(){var t=this;this.$refs.dataForm.validate((function(e){if(e){var a=t.dataFormModel.hosts||"";a=a.trim();var o={key:t.dataFormModel.key,protocol:t.dataFormModel.protocol,remark:t.dataFormModel.remark,hosts:a.length>0?a.split(",").map((function(t){return t.trim()})):[],prefix:t.dataFormModel.prefix,service_name:t.dataFormModel.service_name,status:t.dataFormModel.status,plugins:t.dataFormModel.plugins,props:JSON.parse(t.dataFormModel.propsData)};h(o).then((function(){t.dialogFormVisible=!1,t.getList(),t.$notify({title:"完成",message:"提交成功",type:"success",duration:2e3}),t.getList()}))}}))},handleDelete:function(t){var e=this,a="<span>确定删除路由配置?</span>\n                    <p>\n                    <span>如确删除请输入<strong>[".concat(t.prefix,"]</strong></span>");this.$prompt(a,"提示",{confirmButtonText:"确定",cancelButtonText:"取消",dangerouslyUseHTMLString:!0,type:"warning",beforeClose:function(a,o,r){"confirm"===a?t.prefix===o.inputValue?r():e.$message.error("输入内容不匹配"):r()}}).then((function(){b({key:t.key}).then((function(){e.getList(),e.$notify({title:"完成",message:"删除成功",type:"success",duration:2e3}),e.getList()}))}))}}},k=M,x=(a("d590"),Object(c["a"])(k,o,r,!1,null,"756a337f",null));e["default"]=x.exports}}]);