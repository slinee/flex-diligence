export const extensions = ['pdf','docx','xlsx','xls','csv','txt','md','json','pptx','png','jpg','jpeg','webp'];
export const MAX_FILES=15;export const MAX_FILE_BYTES=10*1024*1024;export const MAX_TOTAL_BYTES=40*1024*1024;
export function validateFiles(files:unknown,existing=0):string|null {
 if(!Array.isArray(files)||!files.length)return 'Choose at least one file.';
 if(files.length+existing>MAX_FILES)return 'A deal can contain up to 15 documents.';
 let total=0;for(const file of files){if(!file||typeof file!=='object'||typeof file.name!=='string'||!Number.isFinite(file.size)||file.size<0)return 'Invalid file metadata.';const ext=file.name.split('.').pop()?.toLowerCase();if(!ext||!extensions.includes(ext))return `${file.name}: unsupported format.`;if(file.size>MAX_FILE_BYTES)return `${file.name}: limit is 10 MB per file.`;if(file.size===0)return `${file.name}: the file is empty.`;total+=file.size;}
 if(total>MAX_TOTAL_BYTES)return 'A deal’s document set must be 40 MB or less.';return null;
}
