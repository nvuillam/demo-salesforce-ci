global with sharing class MyCalendarButtonsPicklist extends VisualEditor.DynamicPickList{
    
    global override VisualEditor.DataRow getDefaultValue(){
        VisualEditor.DataRow defaultValue = new VisualEditor.DataRow('Day, Week & Month', 'agendaDay,agendaWeek,month');
        return defaultValue;
    }
    global override VisualEditor.DynamicPickListRows getValues() {
        VisualEditor.DataRow value1 = new VisualEditor.DataRow('Day, Week & Month', 'agendaDay,agendaWeek,month');
        VisualEditor.DataRow value2 = new VisualEditor.DataRow('All', 'agendaDay,agendaWeek,month,list');
        VisualEditor.DataRow value3 = new VisualEditor.DataRow('Week & Month', 'agendaWeek,month');
        VisualEditor.DataRow value4 = new VisualEditor.DataRow('Day & Month', 'agendaDay,month');
        VisualEditor.DataRow value5 = new VisualEditor.DataRow('List', 'list');
        VisualEditor.DataRow value6 = new VisualEditor.DataRow('None', '');
        VisualEditor.DynamicPickListRows  myValues = new VisualEditor.DynamicPickListRows();
        myValues.addRow(value1);
        myValues.addRow(value2);
        myValues.addRow(value3);
        myValues.addRow(value4);
        myValues.addRow(value5);
        myValues.addRow(value6);
        return myValues;
    }
}