"""Share write-ack state only inside structurally identical FIFO groups."""
from pathlib import Path
import hashlib
import itertools
import json
import re


def transform(folder,report):
    path=Path(folder)/'ResGRU.v';text=path.read_text()
    assert '// E44_SHARED_WRITE_ACK' not in text
    payload=re.compile(r'(?m)^ResGRU_fifo_\w+_ShiftReg\s+#\([^\n]+\)\s+(\w+)_payload\s*\(\n(.*?)\);',re.S)
    groups={}
    for m in payload.finditer(text):
        instance,body=m.groups();assert instance.endswith('_U')
        prefix=instance[:-2]
        group=int(re.search(r'\.we\(fifo_shared_(\d+)_push\)',body)[1])
        groups.setdefault(group,[]).append(prefix)
    assert len(groups)==18 and sum(map(len,groups.values()))==566
    blocks=list(re.finditer(r'always @ \(posedge ap_clk\) begin\n.*?\nend',text,re.S))
    def compact(s):return re.sub(r'\s+','',s)
    replacements=[];aliases=[];proof=[]
    for group,members in sorted(groups.items()):
        leader=members[0];leader_flag='ap_sync_reg_channel_write_'+leader
        leader_block=None
        for prefix in members:
            flag='ap_sync_reg_channel_write_'+prefix
            sync='ap_sync_channel_write_'+prefix;done='ap_channel_done_'+prefix
            init=list(re.finditer(r'(?m)^#0\s+'+re.escape(flag)+r"\s*=\s*1'b0;[^\S\n]*$",text))
            declaration=list(re.finditer(r'(?m)^reg\s+'+re.escape(flag)+r';',text))
            block=[b for b in blocks if re.search(r'\b'+re.escape(flag)+r'\s*<=',b[0])]
            assert len(init)==len(declaration)==len(block)==1,prefix
            normalized=compact(block[0][0].replace(prefix,'CHANNEL'))
            if prefix==leader:leader_block=normalized
            assert normalized==leader_block,(group,prefix,'Different state transition')
            assert compact(re.search(r'assign\s+'+re.escape(done)+r'\s*=\s*(.*?);',text)[1])==compact(
                "(("+flag+" ^ 1'b1) & Block_entry_split_proc_U0_ap_done)"),prefix
            assignment=re.search(r'assign\s+'+re.escape(sync)+r'\s*=\s*(.*?);',text)[1]
            equation=re.sub(r'[\s()]','',assignment)
            expected=[done+'&'+prefix+'_full_n|'+flag,prefix+'_full_n&'+done+'|'+flag]
            assert equation in expected,(prefix,equation)
            if prefix!=leader:
                alias=re.search(r'assign\s+'+re.escape(prefix+'_full_n')+r'\s*=\s*(\w+);',text)
                assert alias and alias[1]==leader+'_full_n',(group,prefix,'FIFO full flags differ')
                replacements.extend([(init[0].start(),init[0].end(),''),
                    (declaration[0].start(),declaration[0].end(),'wire    '+flag+';'),
                    (block[0].start(),block[0].end(),'')])
                aliases.append('assign '+flag+' = '+leader_flag+';')
            proof.append({'group':group,'channel':prefix,'shared_state':leader_flag,'leader':prefix==leader})
    # Identical initial state, clock/reset, completion and full flags imply
    # identical next state. This local induction is valid for arbitrary stalls.
    for state,done,cont,reset,full in itertools.product([0,1],repeat=5):
        old=0 if reset or (done and cont) else (((not state) and done and full) or state)
        canonical=0 if reset or (done and cont) else (state or (done and full))
        assert int(old)==int(canonical)
    assert len(aliases)==548 and len(replacements)==1644
    result=text
    for start,end,value in sorted(replacements,reverse=True):result=result[:start]+value+result[end:]
    assert result.count('endmodule //ResGRU')==1
    result=result.replace('endmodule //ResGRU','// E44_SHARED_WRITE_ACK\n'+'\n'.join(aliases)+'\nendmodule //ResGRU')
    assert len(re.findall(r'(?m)^reg\s+ap_sync_reg_channel_write_\w+;',result))==18
    assert len(re.findall(r'always @ \(posedge ap_clk\) begin\n.*?\nend',result,re.S))==20
    path.write_text(result)
    data={'original_state_bits':566,'shared_state_bits':18,'logical_state_bits_removed':548,
        'payload_storage_changed':False,'fifo_capacity_changed':False,'datapath_changed':False,
        'proof':'Within each existing FIFO group, equal zero initialization and identical clock/reset, producer done/continue, full flag and state update imply equal per-channel acknowledgment state by induction. Replace follower states with the group leader. No assumption of unstalled traffic.',
        'boolean_transition_cases_checked':32,'channels':proof,
        'original_sha256':hashlib.sha256(text.encode()).hexdigest(),'candidate_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    Path(report).write_text(json.dumps(data,indent=2)+'\n')
    return data
