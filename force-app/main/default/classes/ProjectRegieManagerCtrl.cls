public class ProjectRegieManagerCtrl {

    public Project__c[] SelectedProjects{get;set;}
    
    public TimeSheetWrapperList[] tsWrapper{get;set;}
    
    public PreFacture__c[] InvoicesToEmit{get;set;}

    public Map<Id,ProjectLine__c> projectLineDefs{get;set;}
    
    public static final String[] months = new String[]{'noen','Janvier','Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre','Novembre', 'Décembre'};
           
    public ProjectRegieManagerCtrl(ApexPages.StandardSetController ssc){
        Id[] sid = new Id[]{};
        for(SObject so : ssc.getRecords())
			sid.add(so.Id);
         this.initItems(sid);
    }
    
    public ProjectRegieManagerCtrl(ApexPages.StandardController sc){
        this.initItems(new Id[]{sc.getId()});
    }
    
    public void initItems(Id[] projectIds){
        this.SelectedProjects = [SELECT Id, Name, NbJoursVendus__c ,TJMAffecte__c,TJMRegie__c, SoldeAcompte__c/*,Contract__c*/,TotalFunctional__c, TotalTechnical__c, TotalTraining__c, Account__c,
                                 		(SELECT Id, Duration__c,Date__c,DurationCustomer__c,  DurationTotal__c ,CARealise__c, PreFacture__c , User__c, User__r.Name,ProjectLine__r.SectionAnalytique__c, ProjectLine__r.DescriptionFacture__c,ProjectLine__r.Prestation__c,ProjectLine__r.Name, ProjectLine__r.unitRate__c,ProjectLine__r.Type__c from TimeSheets__r WHERE ProjectLine__r.type__c != 'Forfait' AND PreFacture__c='' LIMIT 1300 ),
                                        (SELECT Id, Name, UnitRate__c, SoldAmount__c,DescriptionFacture__c, Type__c,SectionAnalytique__c FROM ProjectLines__r),
                                 		(SELECT Id,User__c,TJMEndDate__c, TJMStartDate__c , TJMFunctional__c, TJMTraining__c, TJMTechnical__c, TJMSousTraitant__c  from ProjectMembers__r ),
                                 		(SELECT Id, Montant__c, NbJours__c, Produit__c,Name, TJM__c/*, Actif__r.Name, Actif__r.Product2.Name, actif__r.TJM__c*/ from AffectationsActifs__r)
                                 FROM Project__c where Id in : projectIds];
        tsWrapper = new List<TimeSheetWrapperList>();


        this.projectLineDefs = new Map<Id,ProjectLine__c>([SELECT id, Name, Type__c,Project__c,UnitRate__c, invoicedQuantity__c, invoicedAmount__c,SectionAnalytique__c,
        (SELECT id, NbJours__c, Montant__c,SectionAnalytique__c FROM AffectationsActifs__r),
        (SELECT id, PreFacture__c, InvoicedQuantity__c,SectionAnalytique__c FROM LignesFacture__r) FROM ProjectLine__c WHERE Project__c in :projectIds]);

        for(Project__c p : this.SelectedProjects){
        	TimeSheetWrapperList tslist = new TimeSheetWrapperList(p);
            tslist.projectLineDefs = this.projectLineDefs;
            tsWrapper.add(tslist);
        }
    }

    public PageReference createAssetInvoice(){
        for(TimeSheetWrapperList t : this.tsWrapper){
            t.recompute();
            t.createInvoice();
        }
        return null;
    }
    
    public PageReference SaveAll(){
        PageReference ret;
        Boolean isError = false;
        for(TimeSheetWrapperList t : this.tsWrapper){
            system.Savepoint sp = Database.setSavepoint();
            try{
                t.save();
            }catch(Exception e){
                system.debug('CATCHED Exception'+ e.getMessage());
                system.debug(e.getStackTraceString());
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, e.getMessage()));
                Database.rollback(sp);
                t.hasError = true;
            }
        }
        
        if(this.tsWrapper.size() == 1 && !tsWrapper.get(0).hasError)
            ret = new PageReference('/'+tsWrapper.get(0).preFacture.Id);
        return ret;
    }
    
    public class TimeSheetWrapperList{
        public Decimal totalPrice {get;set;}
        public Decimal totalDuration{get;set;}
        
        public Map<Id,TimeSheetWrapper[]> timeSheetsByLine{get;set;}
        public map<Id, ProjectLine__c> projectLineDefs{get;set;}

        public Project__c Project{get;set;}
        public ProjectLine__c AcompteLine{get;set;}
        public Decimal defaultTJM{get;set;}
        public Map<Id, List<ProjectMember__c>> projectMembers {get;set;}
        public Boolean hasError;
        public PreFacture__c preFacture {get;set;}
        public String AcompteMode{get;set;}
        public List<assetTupple> assetsTU{get;set;}

        //TPR Replace List by Map to increase the Visualforce limit of 1000 items in the collection
        public Map<Id, TimesheetWrapper> getTimesheets(){
            Map<Id, TimesheetWrapper> ret = new Map<Id, TimesheetWrapper>();
            for(Id tlId : this.timeSheetsByLine.keySet()){
                for(TimesheetWrapper twr : this.timeSheetsByLine.get(tlId)){
                    ret.put(twr.ts.Id, twr);
                }
            }
            return ret;
        }

        public TimeSheetWrapperList(Project__c p){
            this.Project = p;
            this.AcompteMode = 'None';
            for(ProjectLine__c pl : p.projectLines__r){
                if(pl.Type__c == 'Acompte'){
                    this.AcompteLine = pl;
                    this.AcompteMode = 'Solde';
                    break;
                }
            }
            this.defaultTJM = p.TJMAffecte__c == null ? p.TJMRegie__c : p.TJMAffecte__c;
            this.timeSheetsByLine = new Map<Id,TimeSheetWrapper[]>{};
            this.totalPrice = 0;
            this.totalDuration = 0;
                //Construction d'une map de TJM
            //1, on regarde en priorité le tjm du consultant si renseigné
            this.projectMembers = new Map<Id, List<ProjectMember__c>>();
            for(ProjectMember__c pm : p.ProjectMembers__r){
                if(!this.projectMembers.containsKey(pm.User__c))
                	this.projectMembers.put(pm.User__c, new List<ProjectMember__c>());
                this.projectMembers.get(pm.User__c).add(pm);
            }

            for(TimeSheet__c t : p.TimeSheets__r){
                this.addTimesheet(t);
            }
        }
        public void addTimesheet(TimeSheet__c ts){
            TimeSheetWrapper tsw = new timeSheetWrapper(ts, this.projectMembers.containsKey(ts.User__c) ?  this.projectMembers.get(ts.User__c) : null);
            tsw.invoiceableTJM = tsw.invoiceableTJM != null ? tsw.invoiceableTJM : this.defaultTJM;
            //tsw.invoiceableDuration = ts.DurationTotal__c;
            if( tsw.bSelected ) {
                this.totalPrice 	+= tsw.invoiceableTJM * tsw.ts.DurationCustomer__c;
                this.totalDuration 	+=  tsw.ts.DurationCustomer__c;
            }
            if(!this.timeSheetsByLine.containsKey(ts.ProjectLine__c))
                this.timeSheetsByLine.put(ts.ProjectLine__c,new List<TimeSheetWrapper>());
            this.timeSheetsByLine.get(ts.ProjectLine__c).add(tsw);
        }
        
        public Decimal getRemainingAfterOperation(){
            return this.Project.NbJoursVendus__c - this.totalDuration;
        }
        
        public void recompute(){
            this.totalPrice = 0;
            this.totalDuration = 0;
            for(TimeSheetWrapper[] tl : this.timeSheetsByLine.values()) {
                for (TimeSheetWrapper t : tl) {
                    if (t.bSelected) {
                        this.totalPrice += t.invoiceableTJM * t.ts.DurationCustomer__c;
                        this.totalDuration += t.ts.DurationCustomer__c;
                    }
                }
            }
        }
        
        public PreFacture__c createInvoice(){

            PreFacture__c ret = new PreFacture__c(Project__c = this.Project.Id, Name='TMP-'+(Math.random()*10000).round(), Fait_generateur__c = 'Facture Régie au mois', percent_Facture__c = 100);
            Map<ProjectLine__c,Map<Integer,Decimal>> LinesToInvoice = new Map<ProjectLine__c,Map<Integer,Decimal>>();
                
            Decimal montantHT = 0;
            Decimal totalDays = 0;
            for(TimeSheetWrapper[] tl : this.timeSheetsByLine.values()){
                for(TimeSheetWrapper t : tl) {
                    if (t.bSelected && t.ts.ProjectLine__r.Prestation__c != 'Pre-Sales') {
                        Decimal montantTS = (t.invoiceableTJM * t.ts.DurationCustomer__c).setScale(2);
                        montantHT += montantTS;
                        totalDays += t.ts.DurationCustomer__c;
                        if (!LinesToInvoice.containsKey(t.ts.ProjectLine__r))
                        LinesToInvoice.put(t.ts.ProjectLine__r, new Map<Integer, Decimal>{
                        0 => 0, 1 => 0
                        });
                        LinesToInvoice.get(t.ts.ProjectLine__r).put(0,
                                        LinesToInvoice.get(t.ts.ProjectLine__r).get(0) + t.ts.DurationCustomer__c);
                        LinesToInvoice.get(t.ts.ProjectLine__r).put(1,
                                        LinesToInvoice.get(t.ts.ProjectLine__r).get(1) + montantTS);
                    }
                }
            }
            if( AcompteMode != 'None' && this.AcompteLine != null){
                    decimal ImputationAcompte = AcompteMode == 'Solde' ? Math.Max( - montantHT, - this.AcompteLine.SoldAmount__c ) : - montantHT;
                    LinesToInvoice.put(this.AcompteLine, new Map<Integer, Decimal>{0 => 0, 1 => ImputationAcompte });
                    montantHT += ImputationAcompte;
                	if(montantHT == 0)
                		ret.Name.replace ( 'TMP-' , ( this.AcompteLine.SoldAmount__c + ImputationAcompte < 0 ?'FAE-':'PCA-' ) );
            }
            ret.Date_emission__c = getRegieDate();
            ret.Project__c = this.Project.Id;
            ret.Montant_HT__c = montantHT;
            ret.Description__c = 'Projet Salesforce - '+BusinessAnalyticsManager.getMonthLocale(ret.Date_emission__c.month())+' '+ret.Date_emission__c.year()+'\n';

            this.assetsTU = new List<assetTupple>();
            for(ProjectLine__c line : LinesToInvoice.keySet()){
                ret.Description__c += this.generateDesc(LinesToInvoice.get(line).get(0), LinesToInvoice.get(line).get(1),line);
                assetTupple tu = new AssetTupple(this.createAsset( LinesToInvoice.get(line).get(0), LinesToInvoice.get(line).get(1),line.Name, line.Type__c=='Acompte'), line.SectionAnalytique__c, line.Type__c=='Acompte' );
                tu.linkedasset.ProjectLine__c = line.id;
                this.assetsTU.add(tu);
            }
            ret.Description__c += 'Soit un montant total de '+FactureForfait.formatCurrency(ret.Montant_HT__c) +' €';
            ret.preFactureRegie__c = true;
            this.preFacture = ret;
            return this.preFacture;
        }
        
        private AffectationActif__c createAsset(Decimal nbJoursFacture, Decimal montantType, String LineName, Boolean isAcompte){
            AffectationActif__c aToIns ;

            if( nbJoursFacture != 0 || isAcompte){ //On se rend compte qu'on a passé plus de jours sur le produit de ce type, donc on crée un actif avec ce qu'il reste a facturer
            	//Decimal remaining =  totalProject - affected;
                aToIns = new AffectationActif__c(Project__c = this.Project.Id, Montant__c = montantType, nbJours__c = nbJoursFacture, Name = LineName.ToUpperCase() + (isAcompte ? '' : ' '+nbJoursFacture+ ' JOURS' ), Date__c = getRegieDate() );
            }else{
                System.debug('noAssetToCreate');
            }
            return aToIns;
        }

        public Boolean save(){
            System.debug('Saving TimeSheetWrapperList');
            this.hasError = false;
            List<AffectationActif__c> assetToIns = new List<AffectationActif__c>();

            //Cas régie => on crée les actifs et on créée les lignes de facture
            Map<Id,LigneFacture__c> ligneFacturesByIds = new Map<Id,LigneFacture__c>{};
            insert this.preFacture;
            for(assetTupple a : this.assetsTU){
                if( a.linkedasset.nbJours__c > 0 || a.isAcompteInput){
                    if(a.bSelected)
                        assetToIns.add(a.linkedasset); //Cas on crée une affectation d'actif
                    else{
                        //Cas on ratache notre ligne de facture a l'affectation d'actif
                        ligneFacturesByIds.put( a.linkedasset.ProjectLine__c,  createLigneFacture(a.linkedasset,this.preFacture.id, a.SectionAnalytique));
                    }
                }
            }

            if (!assetToIns.isEmpty()) {
                insert assetToIns;
                Map<Id,AffectationActif__c> atoIns2 = New Map<Id,AffectationActif__c> ([SELECT id, SectionAnalytique__c FROM AffectationActif__c WHERE Id in : assetToIns]);
                for (AffectationActif__c a : assetToIns) {
                    LigneFacture__c lf = createLigneFacture(a,this.preFacture.id, atoIns2.get(a.id).SectionAnalytique__c);
                    ligneFacturesByIds.put(a.ProjectLine__c, lf);
                }
            }
            if (!ligneFacturesByIds.isEmpty())
                insert ligneFacturesByIds.values();

            List<TimeSheet__c> tsToUp = new List<TimeSheet__c>();
            for(TimeSheetWrapper[] tl : this.timeSheetsByLine.values()){
                for(TimeSheetWrapper t : tl) {
                    if (t.bSelected) {
                        t.ts.PreFacture__c = this.preFacture.Id;
                        t.ts.CARealise__c =
                                t.getTotalTimesheet(); //On met a jour les champs de CA réalisé qui sont potentiellement vides ou erronés
                        t.ts.Bonus__c = t.getTotalTimesheet();
                        t.ts.LigneFacture__c = ligneFacturesByIds.get(t.ts.ProjectLine__c).Id;
                        tsToUp.add(t.ts);
                    }
                }
            }
            update tsToUp;
            return true;
        }

        public void rollbackSave(){
            this.preFacture = this.preFacture.clone(false, true);
        }
        
        private String generateDesc( decimal nbJours,decimal montant, ProjectLine__c l){
            String ret = '';
            if(l.Type__c == 'Acompte')
                ret += l.DescriptionFacture__c + ' (Solde précédent ' + FactureForfait.formatCurrency(l.SoldAmount__c) + ' €) : '+FactureForfait.formatCurrency(montant) + ' € \n';
            else
                ret += nbJours+' jours '+l.DescriptionFacture__c+' : '+FactureForfait.formatCurrency(montant) + ' € \n';
            return ret;
        }
    }

    private static LigneFacture__c createLigneFacture(AffectationActif__c a, id FactureId, String SectionAnalytique){
       return new LigneFacture__c(PreFacture__c = FactureId,SectionAnalytique__c=SectionAnalytique, Name =a.Name, ProjectLine__c = a.ProjectLine__c, InvoicedQuantity__c = a.NbJours__c, InvoicedAmount__c = a.Montant__c, AffectationActif__c = a.id);
    }
    
    public class TimeSheetWrapper{
        public User Consultant {get;set;}
        public Decimal invoiceableTJM{get;set;}
        public Boolean bSelected{get;set;}
        public TimeSheet__c ts{get;set;}

        public timeSheetWrapper(TimeSheet__c t, List<ProjectMember__c> pm){
            this.ts = t;
            this.Consultant =t.User__r;
            if(ts.DurationCustomer__c == null)
                ts.DurationCustomer__c = ts.DurationTotal__c;
            //this.bSelected = t.PreFacture__c == null;
            // TPR Update ASDSBHRI-56 : pre-select only previous months
            this.bSelected = t.PreFacture__c == null ?
                             this.ts.Date__c < Date.today().toStartOfMonth() : false;
            this.invoiceableTJM = t.ProjectLine__r.UnitRate__c;
        }
        
        public Decimal getTotalTimesheet(){
            return this.invoiceableTJM * this.ts.DurationCustomer__c;
        }
        public String getMonth(){
            return months.get(this.ts.Date__c.month()) + ' '+this.ts.Date__c.year();
        }
    }
    
    public class assetTupple{
        public Boolean bSelected {get;set;}
        public String SectionAnalytique{get;set;}
        public AffectationActif__c linkedasset{get;set;}
        public Boolean isAcompteInput {get;set;}

        public assetTupple(AffectationActif__c a, String sa, boolean isAcompte ){
            this.linkedasset = a;
            this.bSelected = true;
            this.SectionAnalytique = sa;
            this.isAcompteInput = isAcompte;
        }
    }

    private static date getRegieDate(){
        return  Date.today().day() < 15 ? Date.today().toStartOfMonth().addDays(-1) : date.today();
    }
}