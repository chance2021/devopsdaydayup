/**
 * Copyright (c) Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See LICENSE in the project root for
 * license information.
 */

package com.microsoft.azure.samples.controller;

import com.microsoft.azure.samples.dao.TodoItemManagementInMemory;
import com.microsoft.azure.samples.model.TodoItem;
import org.primefaces.event.SelectEvent;
import org.primefaces.event.UnselectEvent;

import javax.faces.application.FacesMessage;
import javax.faces.context.FacesContext;
import javax.faces.view.ViewScoped;
import javax.inject.Inject;
import javax.inject.Named;
import java.io.Serializable;
import java.util.List;

@Named("todocontroller")
@ViewScoped
public class TodoListController implements Serializable {

	private static final long serialVersionUID = 1L;

	@Inject
    TodoItemManagementInMemory todoManagement;

    private List<TodoItem> todoItems;

    private TodoItem selectedItem;
    private List<TodoItem> selectedItems;

    private String name;
    private String category;


    public List<TodoItem> getTodoItems() {
        return todoManagement.getTodoItems();
    }

    public void buttonUpdateAction(){
        todoManagement.updateTodoItem(selectedItems);
    }

    public void buttonAddAction(){
        TodoItem addItem = new TodoItem(name, category, false);
        todoManagement.addTodoItem(addItem);
    }


    public void setSelectedItem(TodoItem selectedItem) {
        this.selectedItem = selectedItem;
    }

    public List<TodoItem> getSelectedItem() {
        return selectedItems;
    }

    public void setSelectedItems(List<TodoItem> selectedItems) {
        this.selectedItems = selectedItems;
    }

    public List<TodoItem> getSelectedItems(){
        return selectedItems;
    }

    public void onRowSelect(SelectEvent<TodoItem> event) {
        FacesMessage msg = new FacesMessage("TodoItem Selected", event.getObject().getId().toString());
        FacesContext.getCurrentInstance().addMessage(null, msg);
    }

    public void onRowUnselect(UnselectEvent<TodoItem> event) {
        FacesMessage msg = new FacesMessage("Car Unselected", event.getObject().getId().toString());
        FacesContext.getCurrentInstance().addMessage(null, msg);
    }


    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }
}

