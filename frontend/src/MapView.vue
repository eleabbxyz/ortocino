<script setup>
import { onMounted, onBeforeUnmount, watch, ref } from 'vue'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
const props = defineProps({products:{type:Array,default:()=>[]}})
const emit=defineEmits(['select'])
const holder=ref(null)
let map, layer
const center=[43.9304,11.0402] // Montemurlo, indicativo: NON geocodifica del civico 78
const emojis={'Verdura':'🥬','Frutta':'🍎','Uova':'🥚','Miele':'🍯','Altro':'🌿'}
function draw(){
 if(!map)return
 layer.clearLayers()
 props.products.forEach(p=>{
  const privacy=p.seller_type==='privato'
  const icon=L.divIcon({className:'custom-pin',html:`<span class="pin ${privacy?'private':''}">${emojis[p.category]||'🌿'}</span>`,iconSize:[40,44],iconAnchor:[20,42]})
  const marker=L.marker([p.latitude,p.longitude],{icon}).addTo(layer)
  marker.on('click',()=>emit('select',p))
  if(privacy)L.circle([p.latitude,p.longitude],{radius:190,color:'#c78053',weight:1,fillColor:'#dfa97d',fillOpacity:.1,interactive:false}).addTo(layer)
 })
}
onMounted(()=>{
 map=L.map(holder.value,{zoomControl:false}).setView(center,14)
 L.control.zoom({position:'bottomright'}).addTo(map)
 const tiles=L.tileLayer('https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',{attribution:'&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/attributions">CARTO</a>',maxZoom:19})
 tiles.on('tileerror',()=>{ holder.value?.classList.add('map-problem') })
 tiles.addTo(map)
 L.circleMarker(center,{radius:8,color:'#fff',weight:3,fillColor:'#3483e5',fillOpacity:1}).addTo(map).bindPopup('Via Fornacelle 78: punto iniziale indicativo (non verificato)')
 layer=L.layerGroup().addTo(map)
 draw()
 setTimeout(()=>map?.invalidateSize(),250)
})
watch(()=>props.products,draw,{deep:true})
onBeforeUnmount(()=>{map?.remove();map=null})
</script>
<template><div class="map-wrap"><div ref="holder" class="map"><div class="map-warning">La mappa richiede Internet. Annunci disponibili anche nella lista.</div></div><div class="map-label">📍 Montemurlo · Via Fornacelle 78 (indicativo)</div><div class="map-legend">🟢 Aziende &nbsp; 🟠 Privati: zona indicativa</div></div></template>
