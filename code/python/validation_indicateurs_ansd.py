"""Validation Python des taux de privation par indicateur (EHCVM 2018) contre
les taux ANSD/UNICEF (MODA 2024, Tableau 3). Reproduit, hors Stata, chaque
indicateur des 7 dimensions N-MODA pondere par hhweight et par groupe d'age,
et l'affiche cote a cote avec la reference ANSD. A lancer depuis la racine du
depot : python3 code/python/validation_indicateurs_ansd.py
"""
import pandas as pd, numpy as np
B='Base/2018-2019/SEN_2018_EHCVM_v02_M_Stata/'
def rd(f,**k): return pd.read_stata(B+f,convert_categoricals=False,**k)
K=['grappe','menage']; KI=['grappe','menage','numind']

# ---- base children ----
ind=rd('ehcvm_individu_sen2018.dta')
hh=ind.groupby(K).size().rename('hhsize').reset_index()
ch=ind.merge(hh,on=K,how='left')
ch['grp']=pd.cut(ch.age,[-1,4,14,17],labels=['0-4','5-14','15-17'])

# ---- housing s11 ----
s11=rd('s11_me_sen2018.dta')
s11['m_toilet']=s11.s11q55.isin([7,8,9,10,11,12]).astype(float)
s11.loc[s11.s11q55.isna(),'m_toilet']=np.nan
s11['m_partag']=np.where(s11.s11q56.isna(),np.nan,(s11.s11q56==1).astype(float))
# eau source (NEW faithful def)
src=s11.s11q27a.isin([5,6,12,13,16,17])|s11.s11q27b.isin([5,6,12,13,16,17])
known=s11.s11q27a.notna()|s11.s11q27b.notna()
s11['m_eau_src']=np.where(known,(src&(s11.s11q32!=1)).astype(float),np.nan)
# eau temps
def mins(a,hh,mm):
    t=a.astype(float); h=s11[hh]; m=s11[mm]
    add=h*60+m; return np.where(a.notna()&h.notna(),t+add,t)
tss=mins(s11.s11q29a,'s11q29b_heure','s11q29b_minute')
tsp=mins(s11.s11q31a,'s11q31b_heure','s11q31b_minutes')
mt=((tss>=30)&~np.isnan(tss))|((tsp>=30)&~np.isnan(tsp))
mt=np.where(np.isnan(tss)&np.isnan(tsp),np.nan,mt.astype(float))
onsite=s11.s11q27a.isin([1,2])&s11.s11q27b.isin([1,2])
mt=np.where(np.isnan(mt)&onsite,0.0,mt)
s11['m_eau_tps']=mt
# ordures / surpeuplement
s11['m_ordures']=np.where(s11.s11q54.isna(),np.nan,s11.s11q54.isin([3,5,6]).astype(float))
s11['nb_pieces']=s11.s11q02
# combustible
cv=['s11q53__1','s11q53__2','s11q53__3','s11q53__7','s11q53__8']
comb=np.zeros(len(s11))
for v in cv: comb=np.where((s11[v]>=1)&s11[v].notna(),1,comb)
nmiss=s11[cv].isna().sum(axis=1)
s11['m_combust']=np.where(nmiss>0,np.nan,comb)
H=s11[K+['m_toilet','m_partag','m_eau_src','m_eau_tps','m_ordures','m_combust','nb_pieces']]

# ---- FIES s08a ----
s08=rd('s08a_me_sen2018.dta')
fv=['s08aq04','s08aq05','s08aq06','s08aq07','s08aq08']
sec=np.zeros(len(s08))
for v in fv: sec=np.where((s08[v]==1)&s08[v].notna(),1,sec)
nm=s08[fv].isna().sum(axis=1)
s08['m_securite']=np.where(nm>0,np.nan,sec)
F=s08.groupby(K)['m_securite'].max().reset_index()

# ---- roster s01: acte, parents ----
s01=rd('s01_me_sen2018.dta')
idc='s01q00a' if 's01q00a' in s01.columns else 'numind'
s01=s01.rename(columns={idc:'numind'})
s01['m_acte']=np.where(s01.s01q05.notna(),(s01.s01q05==2).astype(float),np.nan)
mp=np.full(len(s01),np.nan)
mp=np.where((s01.s01q22==2)|(s01.s01q29==2),1.0,mp)
mp=np.where((s01.s01q22==1)&(s01.s01q29==1),0.0,mp)
s01['m_parents']=mp
R=s01[KI+['m_acte','m_parents']]

# ---- work s04 ----
s04=rd('s04_me_sen2018.dta')
idc='s01q00a' if 's01q00a' in s04.columns else 'numind'
s04=s04.rename(columns={idc:'numind'})
hd=['s04q01','s04q02','s04q03','s04q04','s04q05']
s04['h_dom']=s04[hd].fillna(0).sum(axis=1)
allv=hd+['s04q06','s04q07','s04q08','s04q09']
s04['nrep']=s04[allv].notna().sum(axis=1)
s04['eco']=(s04[['s04q06','s04q07','s04q08','s04q09']]==1).any(axis=1).astype(int)
W=s04[KI+['h_dom','nrep','eco']]

# ---- community health (acces a pied STRICT : mode habituel == a pied) ----
co=rd('s02_co_sen2018.dta')
def svc(k):
    s=co[co.s02q00==k][['grappe','s02q01__%d'%k,'s02q02']].copy(); s.columns=['grappe','ex','mo']
    return s.groupby('grappe').agg({'ex':'max','mo':'min'}).reset_index()
h5=svc(5).rename(columns={'ex':'ex5','mo':'mo5'}); h6=svc(6).rename(columns={'ex':'ex6','mo':'mo6'})
CO=h5.merge(h6,on='grappe',how='outer')
# Acces a pied STRICT : mode habituel == a pied (l'existence locale n'implique
# pas l'acces a pied ; on ne retient donc pas ex5/ex6 comme critere)
CO['pfoot']=((CO.mo5==1)|(CO.mo6==1)).astype(int)
CO['m_sante_acces']=(CO.pfoot!=1).astype(float)
CO=CO[['grappe','m_sante_acces']]

# ---- merge everything to children ----
d=ch.merge(H,on=K,how='left').merge(F,on=K,how='left').merge(R,on=KI,how='left')\
    .merge(W,on=KI,how='left').merge(CO,on='grappe',how='left')
# Grappes absentes du module communautaire = prives (comme tout.do : en Stata
# m_sante_acces = (. != 1) vaut 1). On aligne donc la valeur manquante sur 1.
d['m_sante_acces']=d['m_sante_acces'].fillna(1.0)

# education indicators
d['m_scol']=np.where((d.age>=5)&(d.age<=14)&d.scol.notna(),(d.scol==0).astype(float),np.nan)
d['m_alfab']=np.where((d.age>=15)&(d.age<=17)&d.alfab.notna(),(d.alfab==0).astype(float),np.nan)
d['m_neet']=np.where((d.age>=15)&(d.age<=17),((d.scol==0)&(d.activ7j!=1)).astype(float),np.nan)
d['m_trav']=np.where((d.age>=5)&(d.age<=14)&(d.nrep>0)&d.nrep.notna(),((d.eco==1)|(d.h_dom>=1)).astype(float),np.nan)
d['m_surpeup']=np.where(d.nb_pieces.notna()&(d.nb_pieces>0)&d.hhsize.notna(),(d.hhsize/d.nb_pieces>=4).astype(float),np.nan)

def rate(col,grp,restrict=None):
    s=d[d.grp==grp].copy()
    if restrict is not None: s=s[restrict(s)]
    s=s[s[col].notna()]
    if len(s)==0 or s.hhweight.sum()==0: return None
    return 100*np.average(s[col],weights=s.hhweight)

IND=[
 ('Type de toilettes','m_toilet',None,(40.3,39.1,34.1)),
 ('Partage toilettes','m_partag',None,(20.4,19.4,18.6)),
 ('Source eau non amel.','m_eau_src',None,(12.0,10.7,8.5)),
 ("Temps eau >=30",'m_eau_tps',None,(17.7,16.4,13.9)),
 ('Debarras ordures','m_ordures',None,(59.3,58.2,53.0)),
 ('Surpeuplement','m_surpeup',None,(13.3,12.7,11.4)),
 ('Insecurite alim.','m_securite',None,(45.0,46.5,44.9)),
 ('Combustible solide','m_combust',None,(92.3,92.3,91.5)),
 ('Acces sante (pas a pied)','m_sante_acces',None,(79.3,78.5,75.2)),
 ('Acte de naissance','m_acte',lambda s:s.age<15,(31.8,30.1,None)),
 ('Travail enfants','m_trav',None,(None,43.0,None)),
 ('Sep. parentale','m_parents',None,(36.5,41.8,52.8)),
 ('Non-scolarisation','m_scol',None,(None,45.3,None)),
 ('Illettrisme','m_alfab',None,(None,None,28.1)),
 ('NEET','m_neet',None,(None,None,85.7)),
]
grps=['0-4','5-14','15-17']
print(f"{'Indicateur':26s} | {'memoire (0-4/5-14/15-17)':28s} | {'ANSD':22s}")
print('-'*82)
for name,col,restr,ansd in IND:
    m=[rate(col,g,restr) for g in grps]
    ms='/'.join('%5.1f'%x if x is not None else '  -  ' for x in m)
    as_='/'.join('%5.1f'%x if x is not None else '  -  ' for x in ansd)
    print(f"{name:26s} | {ms:28s} | {as_}")
