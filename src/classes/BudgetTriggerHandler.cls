/*****************************************************************
Author   :Ashwin
Date     :15/Mar/2017
Action   :This is handler class of Trigger 'BudgetTriggerHandler' 
          to create new resource requests when a budget is created
******************************************************************/
public class BudgetTriggerHandler {

    @testVisible static private Boolean excepCoverage;
    
    // Prevent budget creation if status is Approved
    public void validateDocketBudgetStatus(List<pse__Budget__c> budgets) {
                
        Set<String> productSet = new Set<String>{Label.Docket_Budget_Default_Product,Label.Presales_Budget_Default_Product};
        
        Map<String,Id> productMap = new Map<String,Id>();
        for (Product2 product : [SELECT Id, Name FROM Product2 WHERE name IN :productSet]) {
            productMap.put(product.Name, product.Id);            
        }

        Set<String> projectSet = new Set<String>();
        for (pse__Budget__c budget : budgets) {
            projectSet.add(budget.pse__Project__c);
        }
        
        Map<String,String> projMap = new Map<String,String>();
        for (pse__Proj__c project : [SELECT Id, Name, pse__Project_Manager__r.pse__Salesforce_User__c
                                        FROM pse__Proj__c
                                       WHERE Id IN :projectSet
                                         AND pse__Project_Type__c LIKE '%Docket%']) {
            projMap.put(project.Id, project.pse__Project_Manager__r.pse__Salesforce_User__c);                            
        }
        
        for (pse__Budget__c budget : budgets) {
            
            // Set default product lookup for presales budget            
            if (budget.pse__Type__c.containsIgnoreCase('Presales')) {
                budget.Product_Description__c = 'Presales';
                budget.Product__c = (productMap.get(Label.Presales_Budget_Default_Product) != null) ? productMap.get(Label.Presales_Budget_Default_Product) : null;
            }            
            
            // Set default product lookup and product description for docket budgets
            if (projMap.keySet().contains(budget.pse__Project__c)) {
                budget.Product_Description__c = 'Account Manager';
                budget.Product__c = (productMap.get(Label.Docket_Budget_Default_Product) != null) ? productMap.get(Label.Docket_Budget_Default_Product) : null;
            }
            
            System.debug('----- budget : ' + budget);                                 
            if (budget.pse__Status__c == 'Approved' && 
                projMap.get(budget.pse__Project__c) != null && projMap.get(budget.pse__Project__c) != UserInfo.getUserId())
                budget.addError(Label.Create_Approved_Docket_Budget_Msg);        
        }             
    }
    
    // Prevent budget creation if status is Approved
    public void validateDocketBudgetStatus(List<pse__Budget__c> budgets, Map<ID,pse__Budget__c> oldBudgetMap) {
        
        Set<String> projectSet = new Set<String>();
        for (pse__Budget__c budget : budgets) {
            projectSet.add(budget.pse__Project__c);
        }
        
        Map<String,String> projMap = new Map<String,String>();
        for (pse__Proj__c project : [SELECT Id, Name, pse__Project_Manager__r.pse__Salesforce_User__c
                                        FROM pse__Proj__c
                                       WHERE Id IN :projectSet
                                         AND pse__Project_Type__c LIKE '%Docket%']) {
            projMap.put(project.Id, project.pse__Project_Manager__r.pse__Salesforce_User__c);                            
        }
        
        for (pse__Budget__c budget : budgets) {
            System.debug('----- budget : ' + budget);                                 
            if (budget.pse__Status__c != oldBudgetMap.get(budget.Id).pse__Status__c && budget.pse__Status__c == 'Approved' && 
                projMap.get(budget.pse__Project__c) != null && projMap.get(budget.pse__Project__c) != UserInfo.getUserId())
                budget.addError(Label.Update_Approved_Docket_Budget_Msg);        
        }        
    }    
    
    // Create resource requests if Management Personnel flag is checked
    public void createResourceRequests(List<pse__Budget__c> budgets) {
        System.debug('----- Entered createResourceRequests method');        
        
        if (excepCoverage == null) excepCoverage = FALSE;
        
        // try {
            List<pse__Resource_Request__c> requests = new List<pse__Resource_Request__c>();
            
            // Get project information from budgets
            Set<String> projectSet = new Set<String>();
            for (pse__Budget__c budget : budgets) {
                projectSet.add(budget.pse__Project__c);
            }
            System.debug('Project Set - ' + projectSet.size());
            
            Map<Id,pse__Proj__c> projectMap = new Map<Id,pse__Proj__c>();
            for (pse__proj__c project : [SELECT id, name, currencyISOCode, pse__Region__c, pse__Practice__c, pse__Group__c,
                                                Client_BusinessUnit_CBU__c, Services_Sub_Services__c, pse__start_date__c, pse__end_date__c
                                          FROM pse__proj__c
                                         WHERE id IN :projectSet]) {
                projectMap.put(project.Id, project);                                
            }
            System.debug('Project Map - ' + projectMap.size());
            
            // Loop through budgets
            for (pse__Budget__c budget : budgets) {
                
                // Check criteria to create requests
                if (budget.Management_Personnel__c == TRUE && budget.Quantity__c != NULL && budget.Quantity__c > 0) {
                                    
                    if (projectMap.get(budget.pse__Project__c) != null) {
                        
                        pse__proj__c project = projectMap.get(budget.pse__Project__c);
                        System.debug('Retrieved project - ' + project);
                    
                        for (Integer i = 1; i <= budget.Quantity__c; i++ ) {
                            
                            // Create resource request
                            pse__Resource_Request__c request = new pse__Resource_Request__c();
                            request.pse__Opportunity__c = budget.pse__Opportunity__c;
                            request.Budget__c = budget.Id;
                            request.pse__SOW_Hours__c = budget.Hours_Booked__c / budget.Quantity__c;
                            request.CurrencyIsoCode = project.CurrencyIsoCode;
                            request.pse__Requested_Bill_Rate__c = budget.Bill_Rate__c;
                            request.pse__Project__c = project.Id;
                            request.pse__Start_Date__c = (budget.Start_Date__c == null) ? budget.pse__Effective_Date__c : budget.Start_Date__c;
                            request.pse__End_Date__c = budget.End_Date__c;
                            request.pse__Region__c = project.pse__Region__c;
                            request.pse__Practice__c = budget.Practice__c;
                            request.pse__Group__c = project.pse__Group__c;
                            request.Client_Business_Unit_CBU__c = project.Client_BusinessUnit_CBU__c;
                            request.Services_Sub_Services__c = project.Services_Sub_Services__c;
                            request.pse__Resource_Role__c = budget.Product_Description__c;                        
                            
                            System.debug ('Request ' + i + ' to be inserted - ' + request);
                            
                            // add to requests list
                            requests.add(request);
                            
                        }
                    }
                }
            }
            
            System.debug('List of requests - ' + requests.size());
            
            if (requests.size() > 0) {
                Database.SaveResult[] srList = Database.insert(requests, true);
                System.debug(srList);
            }
            /*
            if (excepCoverage) Integer i = 1/0;
            
        } catch (exception e) {
            System.debug(e.getMessage() + ' - ' + e.getLineNumber());
            String subject = 'Error in budget trigger';
            String body = 'Error Message : ' + e.getMessage() + ' - ' + e.getLineNumber();
            PSACustomUtilityClass.sendEmailToSingleRecipient(UserInfo.getUserId(), subject, body);
        } */
        System.debug('----- Exited createResourceRequests method');
    }
    
    // This method will check if Budget is rejected, uncheck Include in Financials and close related assignments for time entry     
    public void validateBudgetRejection (List<pse__Budget__c> budgetList, Map<ID,pse__Budget__c> oldBudgetMap) {
        
        System.debug('----- Entered validateBudgetRejection method');
        
        List<pse__Budget__c> budgetListToProcess = new List<pse__Budget__c>();
        
        // Check if records are eligible for processing        
        for (pse__budget__c budget : budgetList) {
            if (budget.pse__Status__c != oldBudgetMap.get(budget.ID).pse__Status__c && budget.pse__Status__c != NULL &&
                budget.pse__Status__c == 'Rejected') {
                // Uncheck financials    
                budget.pse__Include_In_Financials__c = FALSE;    
                budgetListToProcess.add(budget);    
            }
        }
        
        System.debug('----- budgetListToProcess size : ' + budgetListToProcess.size());
        
        // Proceed if there are any budgets to be processed and look for assignments to update
        if (budgetListToProcess != NULL && budgetListToProcess.size() > 0) {
            
            List<pse__Assignment__c> assignmentListToUpdate = new List<pse__Assignment__c>();
            // Get budgets and related assignments            
            for (pse__Budget__c budget : [SELECT ID, Name,
                                                 (SELECT ID, Name, pse__Closed_for_Time_Entry__c
                                                    FROM Assignments__r)
                                            FROM pse__Budget__c
                                           WHERE ID IN :budgetListToProcess]) {
                                               
                 if (budget.Assignments__r != NULL && budget.Assignments__r.size() > 0) {
                     for (pse__Assignment__c assignment : budget.Assignments__r) {
                         // Set assignment flag for time entry and add to list
                         assignment.pse__Closed_for_Time_Entry__c = TRUE;
                         assignmentListToUpdate.add(assignment);                                                  
                     }                     
                 }                    
            }
            
            System.debug('----- assignmentListToUpdate size : ' + assignmentListToUpdate.size());
            
            // Bulk update assignment records
            if (assignmentListToUpdate != NULL && assignmentListToUpdate.size() > 0)
                update assignmentListToUpdate;            
        }
    }
}