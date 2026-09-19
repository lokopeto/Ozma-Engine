package koto

import "core:encoding/hxa"
import "core:math"
import "core:slice"
import "core:mem"
import "core:sort"
import "base:runtime"
import "core:os"
import vmath "core:math/linalg"

import "core:bytes"
import "core:strings"
import "core:fmt"

import "core:image"
import "core:image/bmp"
import "core:image/jpeg"
import "core:image/netpbm"
import "core:image/png"
import "core:image/qoi"
import "core:image/tga"

import vk "vendor:vulkan"

import "shared:vma"

Vertex :: struct{
  position: 		vmath.Vector4f32,
  normal:   		vmath.Vector4f32,
  color:    		vmath.Vector4f32,
  uv:     			vmath.Vector2f32,
  tex_i:        u32,
  _pad1:				u32
}

TextureData :: struct{
	mat_type: enum{Diffuse, Normal, Depth},
	type: vk.ImageType,
	data: []u8,
}
Texture :: struct{
	size: vk.Extent3D,
	name: string,
	data: []TextureData
}

Model :: struct{
	vertex:   []Vertex,
	textures: []Texture

	// material: 
}
/*
modelfile_parse :: proc(path: string, allocator: runtime.Allocator) -> (m: Model) {
	dir, ext := os.dir(path), os.ext(path)
	data, err := os.read_entire_file(path, allocator)
	
	if err == os.General_Error.None {
		switch ext {
			case ".obj":
				obj := tinyobj.parse_obj(string(data), dir, tinyobj.FLAG_TRIANGULATE)
				// print(obj.shapes[:])

				textures := new([dynamic]Texture, allocator)
				for mat, mat_i in obj.materials {
					if len(mat.diffuse_texname) <= 0 { continue }
					tex: Texture
					// read texture
					diff_path, _ := os.join_path({dir,mat.diffuse_texname}, allocator)
					
					diff_img, read_err := image.load_from_file(diff_path)
					if read_err == .Unable_To_Read_File {
						files, folder_err := os.read_directory_by_path(dir, 0, allocator)
						if folder_err != os.General_Error.None {
							continue
						}
						str := strings.to_upper_snake_case(mat.diffuse_texname)
						read_err : image.Error
						for f in files {
							str_entry := strings.to_upper_snake_case(f.name)
							if str_entry == str {
								diff_img, read_err = image.load_from_file(f.fullpath)
								break
							}
						}
						if read_err != image.General_Image_Error.None {
							continue
						}
					}

					// read texture bytes
					diff_imgBytes := bytes.buffer_to_bytes(&diff_img.pixels)
					
					tex.size = {u32(diff_img.width), u32(diff_img.height), u32(diff_img.depth)}
					
					tex.data = make([]TextureData, 1)
					tex.data[0].data = diff_imgBytes
					tex.data[0].type = .D2
					tex.data[0].mat_type = .Diffuse
					
					// diff_len := len(diff_imgBytes) / diff_img.channels

					// tex.data = make([]TextureData, diff_len, allocator)
					// for &data, i in tex.data {
					// 	data.w = 255
					// 	for channels_i in 0..<diff_img.channels {
					// 		data[channels_i] = diff_imgBytes[i * diff_img.channels + channels_i]
					// 	}
					// }
					append(textures, tex)
				}
				// print(len(obj.materials), len(textures))
				m.textures = slice.clone(textures[:], allocator)
				delete_dynamic_array(textures^)
			
				m.vertex = make([]Vertex, len(obj.attrib.faces), allocator)
				// print(obj.attrib.faces)
				vertex_index, normals_index, uv_index, tex_index: int
				
				normals_len := len(obj.attrib.normals)
				uv_len := len(obj.attrib.texcoords)
				for &v, k in m.vertex {
					vertex_index = obj.attrib.faces[k].v_idx * 3
					normals_index = obj.attrib.faces[k].vn_idx * 3
					uv_index = obj.attrib.faces[k].vt_idx * 2
					tex_index = int(f32(k) / 3.0)
				
					v.position.x = obj.attrib.vertices[vertex_index]
					v.position.y = obj.attrib.vertices[vertex_index + 1]
					v.position.z = obj.attrib.vertices[vertex_index + 2]

					if normals_index < normals_len {
						v.normal.x = obj.attrib.normals[normals_index]
						v.normal.y = obj.attrib.normals[normals_index + 1]
						v.normal.z = obj.attrib.normals[normals_index + 2]
					}

					v.uv.x = obj.attrib.texcoords[uv_index]
					v.uv.y = 1 - obj.attrib.texcoords[uv_index + 1]
					
					if tex_index < len(obj.attrib.material_ids){
						v.tex_i = u32(obj.attrib.material_ids[tex_index])
					}
				}
				// print(len(obj.attrib.vertices[:]))
				// print(len(obj.attrib.material_ids[:]))
				// print(len(m.vertex[:]) / 3)
				// print(obj.attrib.texcoords)
				// print(uv_lencur, uv_len)
				return
			case ".gltf":
				break
		}
	}

	return
}
*/
load_hxa :: proc(path: string, allocator: runtime.Allocator) -> (m: Model) {
	path_abs, _ := os.get_absolute_path(path, allocator)
	file, err := hxa.read_from_file(path_abs)

	for n, n_i in  file.nodes {
		switch v in n.content {
	 		case hxa.Node_Geometry:
				print("Node ", n_i,": Node_Geometry", sep="")
	 		case hxa.Node_Image:
				print("Node ", n_i,": Node_Image", sep="")
		}
	}
	
	idx3,
	idx2: int
	m.vertex = make([]Vertex,file.nodes[0].content.(hxa.Node_Geometry).vertex_count)
	/*
	*/
	for &v,i in m.vertex {
		idx3 = i * 3
		idx2 = i * 2

		v.position.x = f32(file.nodes[0].content.(hxa.Node_Geometry).vertex_stack[0].data.([]f32le)[idx3  ])
		v.position.y = f32(file.nodes[0].content.(hxa.Node_Geometry).vertex_stack[0].data.([]f32le)[idx3+1])
		v.position.z = f32(file.nodes[0].content.(hxa.Node_Geometry).vertex_stack[0].data.([]f32le)[idx3+2])
		
		v.normal.x = f32(file.nodes[0].content.(hxa.Node_Geometry).vertex_stack[1].data.([]f32le)[idx3  ])
		v.normal.y = f32(file.nodes[0].content.(hxa.Node_Geometry).vertex_stack[1].data.([]f32le)[idx3+1])
		v.normal.z = f32(file.nodes[0].content.(hxa.Node_Geometry).vertex_stack[1].data.([]f32le)[idx3+2])

		v.uv.x = f32(file.nodes[0].content.(hxa.Node_Geometry).vertex_stack[2].data.([]f32le)[idx2  ])
		v.uv.y = f32(file.nodes[0].content.(hxa.Node_Geometry).vertex_stack[2].data.([]f32le)[idx2+1])

		v.tex_i = u32(file.nodes[0].content.(hxa.Node_Geometry).vertex_stack[3].data.([]i32le)[idx2])
		// v.tex_i = 0
	}

	tex_total, tex_offset: u32
	for node,node_i in file.nodes {
		if node.meta_data[0].name == "type" && node.meta_data[0].value.(string) == "texture" {
			if tex_offset == 0 {
				tex_offset = u32(node_i)
			}
			tex_total += 1
		}
	}

	m.textures = make([]Texture,tex_total)
	for &tex,tex_i in m.textures {
		index := tex_offset + u32(tex_i)
		
		image := file.nodes[index].content.(hxa.Node_Image)
		tex.size = {u32(image.resolution.x), u32(image.resolution.y), u32(image.resolution.z)}
		
		tex.data = make([]TextureData, len(image.image_stack))
		for &img, img_i in image.image_stack {
			tex.data[img_i].data = img.data.([]u8)
			tex.data[img_i].type = vk.ImageType(max(0,int(image.type) - 1))
			tex.data[img_i].mat_type = .Diffuse
		}
	}

	return
}


fence_info :: proc(signaled: bool) -> (r: vk.FenceCreateInfo) {
	r	= { sType = .FENCE_CREATE_INFO }
	if signaled {
		r.flags = {.SIGNALED}
	}
	return
}

semaphore_info :: proc(type: enum {ORIGINAL, BINARY, TIMELINE} = .ORIGINAL, init_value: u64 = 0) -> (r: vk.SemaphoreCreateInfo) {
	r = { sType = .SEMAPHORE_CREATE_INFO }
	if type != .ORIGINAL {
		r.pNext = &vk.SemaphoreTypeCreateInfo{
			sType = .SEMAPHORE_TYPE_CREATE_INFO,
			initialValue = init_value,
			semaphoreType = vk.SemaphoreType(u8(type) - 1)
		}
	}
	return
}


// Prepare a image to a specified layout before pipeline
imgBarrier_Prepare :: proc(cmd: vk.CommandBuffer, image: vk.Image, subresourceRange: vk.ImageSubresourceRange, old: vk.ImageLayout, new: vk.ImageLayout) {
	vk.CmdPipelineBarrier2(cmd, &vk.DependencyInfo {
		sType = .DEPENDENCY_INFO,
		imageMemoryBarrierCount = 1,
		pImageMemoryBarriers = &vk.ImageMemoryBarrier2 {
			image = image,
			subresourceRange = subresourceRange,
			oldLayout = old,
			newLayout = new,
			srcStageMask = {.TOP_OF_PIPE},
			dstStageMask = {.BOTTOM_OF_PIPE},
			
			sType = .IMAGE_MEMORY_BARRIER_2
		}
	})
}

// memBarrier :: proc {

// }

// memCopy_array :: proc() {
// 	buff_slice := mem.byte_slice(buffsrc.info.mapped_data, vexSize_sum)
// 	for &m, i in models {
// 		mem.copy(raw_data(buff_slice[m.offsets.vertex:]), raw_data(m.vertex), len(m.vertex) * size_of(m.vertex[0]))
// 	}
// }


ImgUpload_Info :: struct {
	subresourceRange: vk.ImageSubresourceRange, // For memory barrier
	subresourceLayers: vk.ImageSubresourceLayers,
	extent: vk.Extent3D,
	offset: vk.Offset3D, //Optional

	image: vk.Image,
	allocator: vma.Allocator,	
}
cmdImg_Upload :: proc(
	cmd: vk.CommandBuffer,
	data: []u8, // [pixel][color]u8
	info: ImgUpload_Info
) -> (buffer: vk.Buffer, ok: bool) #optional_ok {
	if len(data) <= 0 { return }
	size_elem := size_of(data[0])
	size := len(data) * size_elem
	len_data := len(data)
	ok = true
	allocation: vma.Allocation
	buff_info := vk.BufferCreateInfo{
		sharingMode = .EXCLUSIVE,
		size = vk.DeviceSize(size),
		usage = {.TRANSFER_SRC},

		sType = .BUFFER_CREATE_INFO
	}
	alloc_info := vma.Allocation_Create_Info {
		usage = .Cpu_Only,
		flags = {.Mapped},
		required_flags = {.DEVICE_LOCAL}
	}
	alloc : vma.Allocation_Info

	vma.create_buffer(
		info.allocator,
		buff_info,
		alloc_info,
		&buffer,
		&allocation,
		&alloc
	)

	mem.copy(alloc.mapped_data, raw_data(data), size)
	imgBarrier_Prepare(cmd, info.image, info.subresourceRange, .UNDEFINED, .TRANSFER_DST_OPTIMAL)


	buff2img_info := vk.CopyBufferToImageInfo2 {
		dstImage = info.image,
		srcBuffer = buffer,
		dstImageLayout = .TRANSFER_DST_OPTIMAL,
		regionCount = 1,
		pRegions = &vk.BufferImageCopy2 {
			// bufferImageHeight & bufferRowLength == 0 { the image size from extent }
			imageSubresource = info.subresourceLayers,
			imageOffset = info.offset,
			imageExtent = info.extent,
			
			sType = .BUFFER_IMAGE_COPY_2
		},
		sType = .COPY_BUFFER_TO_IMAGE_INFO_2,
	}
	vk.CmdCopyBufferToImage2(cmd,&buff2img_info)
	imgBarrier_Prepare(cmd, info.image, info.subresourceRange, .TRANSFER_DST_OPTIMAL, .SHADER_READ_ONLY_OPTIMAL)
	return
}

ImgUploadBulk_Info :: struct {
	subresourceRange: vk.ImageSubresourceRange, // For memory barrier
	subresourceLayers: vk.ImageSubresourceLayers,
	extent: vk.Extent3D,
	offset: vk.Offset3D, //Optional

	image: vk.Image,
	allocator: vma.Allocator,	
}
cmdImg_UploadBulk :: proc(
	cmd: vk.CommandBuffer,
	data: [][][$N]u8, // [images][pixel][color]u8
	info: ImgUploadBulk_Info
) -> (buffer: vk.Buffer, ok: bool) #optional_ok {
	len_data := len(data)
	if len_data <= 0 { return }
	ok = true
	
	size: u32 = 0
	Sizes :: []struct{
		elem: int,
		texel: int,
	}
	sizes := make([]Sizes, len_data)
	offsets := make([]u32, len_data)
	for d,i in data {
		sizes[i].elem = size_of(d[0])
		sizes[i].texel = len(d) * sizes[i].elem
		offsets[i] = size
		size += sizes[i].texel
	}

	buff_info := vk.BufferCreateInfo
	alloc: vma.Allocation_Info
	allocation: vma.Allocation
	vma.create_buffer(
		info.allocator,
		{
			sharingMode = .EXCLUSIVE,
			size = vk.DeviceSize(size),
			usage = {.TRANSFER_SRC},
	
			sType = .BUFFER_CREATE_INFO
		},{
			usage = .Cpu_Only,
			flags = {.Mapped},
			required_flags = {.DEVICE_LOCAL}
		},
		&buffer,
		&allocation,
		&alloc
	)

	
	buff_slice := mem.byte_slice(alloc.mapped_data, vexSize_sum)
	for &f, i in offsets {
		mem.copy(raw_data(buff_slice[f:]), raw_data(data[i]), sizes[i].texel)
	}

	imgBarrier_Prepare(cmd, info.image, info.subresourceRange, .UNDEFINED, .TRANSFER_DST_OPTIMAL)

	buff2img_info := vk.CopyBufferToImageInfo2 {
		dstImage = info.image,
		srcBuffer = buffer,
		dstImageLayout = .TRANSFER_DST_OPTIMAL,
		regionCount = 1,
		pRegions = &vk.BufferImageCopy2 {
			// bufferImageHeight & bufferRowLength == 0 { the image size from extent }
			imageSubresource = info.subresourceLayers,
			imageOffset = info.offset,
			imageExtent = info.extent,
			
			sType = .BUFFER_IMAGE_COPY_2
		},
		sType = .COPY_BUFFER_TO_IMAGE_INFO_2,
	}
	vk.CmdCopyBufferToImage2(cmd,&buff2img_info)
	imgBarrier_Prepare(cmd, info.image, info.subresourceRange, .TRANSFER_DST_OPTIMAL, .SHADER_READ_ONLY_OPTIMAL)
	return
}

calcMip :: proc{
	calcMip_f32,
	calcMip_u32
}
calcMip_f32 :: proc(w, h: f32) -> u32 {
	return u32(math.floor(math.log2(max(w, h)))) + 1
}

calcMip_u32 :: proc(w, h: u32) -> u32 {
	return u32(math.floor(math.log2(max(f32(w), f32(h))))) + 1
}

getAlignedSize :: proc(value, alignment: vk.DeviceSize) -> vk.DeviceSize {
  return (value + alignment - 1) & ~(alignment - 1)
}

print_column :: proc{
	print_column_4f32,
	print_column_3f32
}
print_column_4f32 := proc(m: vmath.Matrix4f32) {
	fmt.print( "",
		m[0][0], m[1][0], m[2][0], m[3][0], "\n",
		m[0][1], m[1][1], m[2][1], m[3][1], "\n",
		m[0][2], m[1][2], m[2][2], m[3][2], "\n",
		m[0][3], m[1][3], m[2][3], m[3][3], "\n",
	)
}
print_column_3f32 := proc(m: vmath.Matrix3f32) {
	fmt.print( "",
		m[0][0], m[1][0], m[2][0], "\n",
		m[0][1], m[1][1], m[2][1], "\n",
		m[0][2], m[1][2], m[2][2], "\n",
	)
}
