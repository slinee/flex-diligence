import type {Deal} from './data';
export type Workspace={id:string;name:string;created:string};
export type Profile={name:string;email:string;role:string};
export type LocalState={version:3;workspaces:Workspace[];activeWorkspace:string;deals:Deal[];profile:Profile};
export const emptyState=():LocalState=>({version:3,workspaces:[],activeWorkspace:'',deals:[],profile:{name:'',email:'',role:''}});
const seedIds=new Set(['northstar','orbit','terra']);
export function migrateLegacy(value:unknown,workspaceId:string,created:string):LocalState{
 const state=emptyState();if(!Array.isArray(value))return state;
 const deals:Deal[]=[];for(const raw of value){if(!raw||typeof raw!=='object'||typeof raw.id!=='string'||typeof raw.name!=='string'||!Array.isArray(raw.documents))continue;const deal=structuredClone(raw) as Deal;
 if(seedIds.has(deal.id)){const real=deal.documents.filter(d=>d&&typeof d.id==='string'&&d.id!==d.name&&(d.path||d.text||/^[0-9a-f-]{36}$/i.test(d.id)));if(!real.length)continue;deal.id=`imported-${deal.id}`;deal.name='Imported documents';deal.tagline='Your previously uploaded evidence';deal.documents=real;deal.sector='Uncategorized';deal.stage='New';deal.valuation='';}
 if(deal.report?.mode!=='live')delete deal.report;deal.workspaceId=workspaceId;deals.push(deal);}
 if(deals.length){state.workspaces=[{id:workspaceId,name:'Imported workspace',created}];state.activeWorkspace=workspaceId;state.deals=deals;}return state;
}
export function readLocalState(storage:Pick<Storage,'getItem'>):LocalState{
 const current=storage.getItem('flex-desk-v3');if(current){const state=JSON.parse(current) as LocalState;if(state.version!==3||!Array.isArray(state.workspaces)||!Array.isArray(state.deals)||!state.profile)throw new Error('Saved workspace could not be read. Your data has not been overwritten.');return state;}
 const legacy=storage.getItem('flex-workspace-v2')||storage.getItem('flex-workspace-v1');return legacy?migrateLegacy(JSON.parse(legacy),crypto.randomUUID(),new Date().toISOString()):emptyState();
}
export function reportMarkdown(report:NonNullable<Deal['report']>){return `# ${report.company}\n\n${report.summary}\n\n${report.sections.map(s=>`## ${s.title}\n\n${s.subsections.map(f=>`### ${f.title}\n\n${f.content}\n\nConfidence: ${f.confidence}\nSources: ${f.sources.join(', ')}`).join('\n\n')}`).join('\n\n')}\n\n## Research\n\n${report.research.map(r=>`### ${r.question}\n\n${r.answer}\n\n${r.citations.join('\n')}`).join('\n\n')}`;}
export type DealMutation=Partial<Omit<Deal,'id'|'workspaceId'|'report'>>;
export function mergeDealMutation(current:Deal,patch:DealMutation):Deal{return {...current,...patch,id:current.id,workspaceId:current.workspaceId,report:current.report};}
